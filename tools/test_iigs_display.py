#!/usr/bin/env python3
"""The C64 port's unchanged game logic drives a Super Hi-Res screen through hal/apple/gs/shr.s (prototype).

The logic (build/c64/game.prg) runs in the 65816 interpreter in emulation mode, laid out as on the C64. After it
sets up a level and runs game steps, the test calls the hardware layer with JSL and compares bank $E1's pixels with
a model built from the logic's own memory (the shown matrix and BPAT). It also compares the level view against the
earlier model built straight from the BBC tiles, and checks the layer touches nothing but its own page.
test_iigs_display.py [steps per level] [seed]"""
import os
import random
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import bbcmem
import iigs_model
import make_apple2gs_tiles as conv
from asm65816 import cc65_bin
from sim65816 import Sim65816
from sim_check import Machine, labels

STEPS = int(sys.argv[1]) if len(sys.argv) > 1 else 120
SEED = int(sys.argv[2]) if len(sys.argv) > 2 else 1
B = ROOT / "build" / "apple2gs"
SENT = 0x0200

# ---- build the layer ---------------------------------------------------------------------------------------
subprocess.run([sys.executable, "-I", str(ROOT / "tools/make_apple2gs_tiles.py")], check=True, stdout=subprocess.DEVNULL)
subprocess.run([sys.executable, "-I", str(ROOT / "tools/make_iigs_logic_syms.py")], check=True, stdout=subprocess.DEVNULL)
b = cc65_bin()
subprocess.run([str(b / "ca65"), "-I", str(B), str(ROOT / "hal/apple/gs/shr.s"), "-o", str(B / "shr.o"), "-l", str(B / "shr.lst")], check=True)
subprocess.run([str(b / "ld65"), "-C", str(ROOT / "hal/apple/gs/shr_test.cfg"), str(B / "shr.o"), "-o", str(B / "shr_test.bin"),
                "-Ln", str(B / "shr_test.lbl")], check=True)
hal_sym = {l.split()[2].lstrip("."): int(l.split()[1], 16) for l in (B / "shr_test.lbl").read_text().splitlines()}
hal_code = (B / "shr_test.bin").read_bytes()
bbc2shr = (B / "bbc2shr.bin").read_bytes()
sym_inc = dict(l.split(" = ") for l in (B / "logic_syms.inc").read_text().splitlines() if " = " in l)
S = {k[2:]: int(v.lstrip("$"), 16) for k, v in sym_inc.items()}
BPAT, MAT_A, MAT_B = S["BPAT"], S["MAT_A"], S["MAT_B"]
SHRCHARS = 0x022000

# ---- the logic (built for the IIgs from src/, loaded at $0801) in the 65816 interpreter, with the display layer in bank 2 ---------
lb = labels(str(B / "logic.lbl"))
logic = (B / "logic.bin").read_bytes()
game_inc = (ROOT / "hal/apple/gs/game.inc").read_text()
HAL_FRAME, HAL_WAIT, HAL_CHAR = (int(re.search(rf"^{n}\s*=\s*\$([0-9a-fA-F]+)", game_inc, re.M).group(1), 16) for n in ("HAL_FRAME", "HAL_WAIT", "HAL_CHAR"))
assert HAL_CHAR + 8 <= 0x0800 and HAL_FRAME >= 0x0763, "the logic's HAL stubs must be clear of the layer's direct page ($0700 - $0762)"

s = Sim65816()
s._io = lambda a: False
s.mem[0x0801:0x0801 + len(logic)] = logic
s.mem[SENT:SENT + 3] = bytes((0x4C, SENT & 255, SENT >> 8))
# the platform's side of the logic's HAL: here nothing waits (frame_wait, wait_frames: RTS), and a character written by the logic goes to the layer
s.mem[HAL_FRAME] = 0x60
s.mem[HAL_WAIT] = 0x60
s.mem[HAL_CHAR:HAL_CHAR + 5] = bytes([0x22, hal_sym["shr_char_hook"] & 255, hal_sym["shr_char_hook"] >> 8 & 255, hal_sym["shr_char_hook"] >> 16, 0x60])
s.e, s.p, s.dp, s.dbr, s.pbr = 1, 0x34, 0, 0, 0
s.sp = 0x01FF
s.mem[0x020000:0x020000 + len(hal_code)] = hal_code      # linked at $020000 (shr_test.cfg)
s.mem[0x021800:0x021800 + len(bbc2shr)] = bbc2shr
s.mem[0xE10000:0xE20000] = bytes([0xA5]) * 0x10000


def call_logic(name, a=None):
    s.push16(SENT - 1)
    s.pc, s.pbr = lb[name], 0
    if a is not None:
        s.c = a
    s.run(5_000_000)
    assert (s.e, s.sp >> 8) == (1, 1)


# what logic_start does before the title screen
call_logic("init_mirror_table")
s.mem[lb["rows_page"]] = S["ROWS"] >> 8
s.mem[lb["add"]] = 5
call_logic("clear_buffers")
call_logic("copy_sprites")
call_logic("new_game")
for level in range(12):
    src = lb["level_tiles0"] + level * 256
    s.mem[0xE000 + level * 256:0xE100 + level * 256] = s.mem[src:src + 256]


LAST_CYCLES = [0]


def present():
    """What the platform does each frame before showing it: the logic stages its sprites (make_sprites), then the layer draws."""
    call_logic("make_sprites")
    before, cyc0 = s.count, s.cycles
    call_hal("shr_present")
    LAST_CYCLES[0] = s.cycles - cyc0
    return s.count - before


def call_hal(name):
    """JSL from the logic's emulation mode to the layer in bank 2; it must come back in emulation mode."""
    s.push(0)                                   # the return bank, then the return address - 1 (what JSL pushes)
    s.push16(SENT - 1)
    s.pc, s.pbr = hal_sym[name] & 0xFFFF, hal_sym[name] >> 16
    before = bytes(s.mem[0:0x10000])
    s.run(2_000_000)
    assert (s.e, s.pbr, s.pc, s.dp, s.dbr, s.sp) == (1, 0, SENT, 0, 0, s.sp) and s.sp >> 8 == 1, \
        f"{name} must return in emulation mode to the caller (e {s.e} pbr {s.pbr:02X} pc {s.pc:04X} dp {s.dp:04X} dbr {s.dbr:02X})"
    after = bytes(s.mem[0:0x10000])
    changed = [i for i in range(0x10000) if before[i] != after[i] and not 0x0700 <= i < 0x0800 and not 0x0100 <= i < 0x0200]
    assert not changed, f"{name} changed logic RAM at ${changed[0]:04X}"


def cell_bytes(code):
    return b"".join(conv.shr_line(s.mem[BPAT + line * 256 + code]) for line in range(8))


def model_from_logic():
    return iigs_model.picture(s.mem, 0, S, lb)


bbc = bbcmem.load()


def level_grid(level):
    """[column][row] of tile numbers as the logic has them: its level map (LTILES, 64 columns x 4 bytes of two nibbles)
    through its translation table level_xlat[level * 16 + nibble]. The map and table are the game's data (the C64 build's
    make_data.py applies the BBC's lift removal and initial-tile patches), so they are taken from the logic's memory."""
    page = s.mem[0xE000 + level * 256:0xE000 + level * 256 + 256]
    xlat = s.mem[lb["level_xlat"] + level * 16:lb["level_xlat"] + level * 16 + 16]
    return [[xlat[(page[c * 4 + (y >> 1)] >> (4 if y & 1 else 0)) & 15] for y in range(8)] for c in range(64)]


def model_from_tiles(level, cam_x, cam_y):
    """The window as the BBC's own tile art draws it: independent of the logic's character building (intern,
    fill_rows, the matrices) and of this layer."""
    grid = level_grid(level)
    out = bytearray()
    for r in range(25):
        lines = [bytearray() for _ in range(8)]
        for c in range(40):
            wx, wy = cam_x + c, cam_y + r
            cell = bbcmem.tile_cell_column(bbc, grid[wx // 4][wy // 4], wx % 4)[wy % 4]
            for i, byte in enumerate(cell):
                lines[i] += conv.shr_line(byte)
        for ln in lines:
            out += ln
    return bytes(out)


def screen():
    return bytes(s.mem[0xE12000:0xE12000 + 32000])


def check(what, level=None):
    got, want = screen(), model_from_logic()
    if got != want:
        first = next(i for i in range(32000) if got[i] != want[i])
        raise AssertionError(f"{what}: screen differs from the logic's matrix at byte {first} (cell row {first // 1280}, "
                             f"col {first % 160 // 4}): got {got[first]:02x} want {want[first]:02x}")
    outside = bytes(s.mem[0xE10000:0xE12000]) + bytes(s.mem[0xE19D00:0xE20000])
    assert outside == bytes([0xA5]) * len(outside), f"{what}: wrote outside the pixel area"
    # every converted character equals the full conversion
    for ch in range(256):
        assert bytes(s.mem[SHRCHARS + ch * 32:SHRCHARS + ch * 32 + 32]) == cell_bytes(ch), f"{what}: character {ch}"


call_hal("shr_init")                                      # the layer zeroes its own tables and state
rnd = random.Random(SEED)
KEYS = [1, 2, 3, 4, 7, 8, 13, 15]


def start_level(level):
    """set_level (it includes init_view). Level 7's real columns are the right half of its page: start at the right end."""
    s.mem[lb["init_px"]] = 0xF8 if level == 7 else 4
    s.mem[lb["arrive_mode"]] = 0
    call_logic("set_level", level)


# ---- 1. no objects and no enemies: the logic's picture must equal the BBC tile picture exactly, on every level
saved = {n: s.mem[lb[n]] for n in ("place_objects", "init_enemies")}
for n in saved:
    s.mem[lb[n]] = 0x60                                   # RTS
for level in range(12):
    start_level(level)
    call_hal("shr_present")                                # (no make_sprites: the sprites would not be in the tile art)
    check(f"bare level {level}")
    cur_w, cur_cam = s.mem[lb["cur_w"]], s.mem[lb["cur_cam"]]
    assert screen() == model_from_tiles(level, cur_w, cur_cam), f"bare level {level}: differs from the BBC tile picture"
    print(f"level {level:2d} bare, window ({cur_w:3d},{cur_cam}): logic -> layer -> pixels equal the picture drawn from the BBC tile art, {s.mem[lb['nchars']]} characters")
for n, v in saved.items():
    s.mem[lb[n]] = v

# ---- 2. the real thing: enemies and objects, random play; every presented screen equals the logic's own matrix
for level in (0, 1, 3, 7, 11):
    start_level(level)
    present()
    check(f"level {level} start")
    held_for, keys, instr = 0, [], []
    for step in range(STEPS):
        if held_for <= 0:
            keys = rnd.sample(KEYS, rnd.choice([0, 1, 1, 2]))
            held_for = rnd.randrange(2, 20)
        held_for -= 1
        s.mem[lb["key1"]], s.mem[lb["key2"]] = (keys[-1], keys[0]) if keys else (0, 0)
        s.mem[lb["lives"]] = 9
        call_logic("game_step")
        if step % 4 == 3:
            for name in ("snap_player", "calc_scroll", "matrix_update", "matrix_update", "matrix_update"):
                call_logic(name)
            instr.append(present())
            check(f"level {level} step {step}")
    print(f"level {level:2d} play: {STEPS} steps, window now ({s.mem[lb['cur_w']]},{s.mem[lb['cur_cam']]}); every presented screen "
          f"equals the logic's matrix; shr_present {min(instr)}-{max(instr)} instructions")

# ---- 3. the window moves: one cell either way (the screen shifts, only the new edge is drawn), several cells, two steps at once
start_level(0)
present()
check("level 0 start")
cost = {}


def move(what, dw=0, dc=0, steps=1):
    """Ask the logic for a window dw columns / dc rows away, let its matrix_update make `steps` single steps, and present."""
    s.mem[lb["t_w"]] = (s.mem[lb["cur_w"]] + dw) & 0xFF
    s.mem[lb["want_cam"]] = (s.mem[lb["cur_cam"]] + dc) & 0xFF
    for _ in range(steps):
        call_logic("matrix_update")
    cost[f"{len(cost) + 1}. {what}"] = (present(), LAST_CYCLES[0])
    check(what)


move("window right 1", dw=1)
move("window right 1", dw=1)
move("window right 1", dw=1)
move("window left 1", dw=-1)
move("window left 1", dw=-1)
move("window left 1", dw=-1)
move("window down 1", dc=1)
move("window down 1", dc=1)
move("window up 1", dc=-1)
move("window up 1", dc=-1)
move("window right 6 (a jump)", dw=6)
move("window left 2 (two steps at once)", dw=-2, steps=2)
move("window down 2 (two steps at once)", dc=2, steps=2)
move("nothing moved")
cost["idle present"] = (present(), LAST_CYCLES[0])
check("idle present")
for what, (n, cyc) in cost.items():
    print(f"  shr_present, {what}: {n} instructions, about {cyc} cycles (estimate; 2.8 MHz frame = 47,000)")
print("iigs display OK")
