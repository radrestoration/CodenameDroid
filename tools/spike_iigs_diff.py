#!/usr/bin/env python3
"""IIgs feasibility spike: does the C64 port's game logic run unchanged on a 65816 in emulation mode?

The same binary (build/c64/game.prg) runs on two independent CPU models - tools/sim6502.py (NMOS 6502, as the
project's own tests use it) and tools/sim65816.py (65C816 in emulation mode, direct page 0, data bank 0). With --split
the 65816 runs the code from bank 0 but every absolute-addressed data access goes to a copy of RAM in bank 1 (data bank
register = 1); the direct page and stack stay in bank 0. From one
starting state both run the same calls (set_level, then game_step with random keys); all RAM except the
C64 I/O area ($D000-$DFFF) and the 6510 port ($00/$01) must be identical after every call.

Nothing here is a refactor: the C64 sources are unchanged.   spike_iigs_diff.py [steps per level] [seed]"""
import os
from pathlib import Path
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from sim_check import Machine, labels
from sim65816 import Sim65816

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
SPLIT = "--split" in sys.argv          # code in bank 0, absolute-addressed data in bank 1 (DBR = 1)
STEPS = int(ARGS[0]) if len(ARGS) > 0 else 150
SEED = int(ARGS[1]) if len(ARGS) > 1 else 1
LEVELS = (0, 1, 2, 3, 7, 11)
SENTINEL = 0x0200
NATIVE_KEYS = [1, 2, 3, 4, 7, 8, 13, 15]               # the game's key numbers (test_vs_bbc.NATIVE_KEY)

lb = labels(os.path.join(HERE, "..", "build", "c64", "game.lbl"))

def init_mirror_table(m, lb):
    """What init_mirror_table (src/init.s) does before the game runs: MIRROR_TABLE[b] = the bits of each nibble of b reversed."""
    assert "MIRROR_TABLE = $0600" in (Path(__file__).resolve().parent.parent / "src/memory.inc").read_text()
    rev = lb["rev_nibble"]
    for b in range(256):
        m[0x0600 + b] = (m[rev + (b >> 4)] << 4 | m[rev + (b & 15)]) & 0xFF

mc = Machine(True)
c6, m6 = mc.cpu, mc.cpu.m
m6[SENTINEL:SENTINEL + 3] = bytes((0x4C, SENTINEL & 255, SENTINEL >> 8))     # JMP $0200: the return target
m6[0xD01A] = 0


class NeedsPlatform(Exception):
    """A routine that waits for the C64's raster, interrupt or keyboard: the harness cannot run it."""


def call6(name, a=None):
    c6.push((SENTINEL - 1) >> 8)
    c6.push((SENTINEL - 1) & 255)
    c6.pc = lb[name]
    if a is not None:
        c6.a = a
    n = 0
    while c6.pc != SENTINEL and n < 5_000_000:
        c6.step()
        n += 1
    if c6.pc != SENTINEL:
        inv = sorted((v, nm) for nm, v in lb.items() if not nm.startswith("@"))
        where = max(t for t in inv if t[0] <= c6.pc)
        raise NeedsPlatform(f"{name} reached {where[1]}+{c6.pc - where[0]}")
    return n


def poke(addr, v):
    s.mem[data_base(addr) + addr] = v


def call816(s, name, a=None):
    s.push16(SENTINEL - 1)
    s.pc = lb[name]
    if a is not None:
        s.c = a
    before = s.count
    s.run(5_000_000)
    return s.count - before


def data_base(lo):
    """Where the 65816 keeps the byte the 6502 has at `lo`: zero page and stack always in bank 0."""
    return 0x10000 if SPLIT and lo >= 0x200 else 0


def load_ram():
    s.mem[:0x10000] = bytes(m6)
    if SPLIT:
        s.mem[0x10000:0x20000] = bytes(m6)


def compare(s, what):
    for lo, hi in ((2, 0x200), (0x200, 0xD000), (0xE000, 0x10000)):
        b0 = data_base(lo)
        a, b = bytes(m6[lo:hi]), bytes(s.mem[b0 + lo:b0 + hi])
        if a != b:
            i = next(k for k in range(len(a)) if a[k] != b[k]) + lo
            near = min((n for n, v in lb.items() if v <= i and not n.startswith("@")), key=lambda n: i - lb[n], default="?")
            raise AssertionError(f"{what}: RAM differs at ${i:04X} (near {near}+{i - lb.get(near, 0)}): "
                                 f"6502 {m6[i]:02X}, 65816 {s.mem[data_base(i) + i]:02X}")


# the same starting state as test_enemy_pool, plus what `start` sets up: a new game and the level tile maps in place
init_mirror_table(m6, lb)
call6("new_game")
for level in range(12):
    src = lb["level_tiles0"] + level * 256
    m6[0xE000 + level * 256:0xE100 + level * 256] = m6[src:src + 256]

# (no interrupts run in this harness, so the routine that waits for frames returns at once on both CPUs)
m6[lb["wait_frames"]] = 0x60
if SPLIT:
    m6[lb["snd_osword"]] = 0x60           # the SID driver patches its own operand (stx @blk+1): impossible with split banks
s = Sim65816()
s._io = lambda a: False              # the C64 charset lives at $C000: no IIgs soft switches in this comparison
load_ram()
s.e, s.p, s.dp, s.dbr, s.pbr = 1, 0x34, 0, 1 if SPLIT else 0, 0
s.sp = 0x100 | c6.sp
compare(s, "initial state")

rnd = random.Random(SEED)
total6 = total816 = 0
reached = []
for level in LEVELS:
    m6[lb["init_px"]] = 4
    m6[lb["arrive_mode"]] = 0
    poke(lb["init_px"], 4)
    poke(lb["arrive_mode"], 0)
    n6 = call6("set_level", level)
    n8 = call816(s, "set_level", level)
    compare(s, f"set_level({level})")
    held_for, keys, done = 0, [], 0
    for step in range(STEPS):
        if held_for <= 0:
            keys = rnd.sample(NATIVE_KEYS, rnd.choice([0, 1, 1, 2]))
            held_for = rnd.randrange(2, 20)
        held_for -= 1
        k1, k2 = (keys[-1], keys[0]) if keys else (0, 0)
        for name, v in (("key1", k1), ("key2", k2), ("lives", 9)):     # (9 lives: no game-over screen, it waits for a key)
            m6[lb[name]] = v
            poke(lb[name], v)
        try:
            n6 = call6("game_step")
        except NeedsPlatform as e:
            reached.append(f"level {level} step {step}: {e}")
            load_ram()                                        # resynchronise and move on to the next level
            c6.sp, s.sp = 0xFF, 0x1FF
            break
        n8 = call816(s, "game_step")
        total6, total816 = total6 + n6, total816 + n8
        compare(s, f"level {level} step {step} keys {keys}")
        done += 1
    print(f"level {level:2d}: {done} game_steps identical (px {m6[lb['px']]}, pc {m6[lb['pc']]}, py {m6[lb['py']]})")
for r in reached:
    print("  stopped (needs the C64 platform):", r)
print(("split banks (code bank 0, data bank 1): " if SPLIT else "") + f"OK: RAM identical after every call; {total6} 6502 and {total816} 65816 instructions executed")
