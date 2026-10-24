#!/usr/bin/env python3
"""Differential test: the same inputs on the original BBC build (bbcsim.py) and on the C64 build
(c64sim.py) must give the same screen buffer and the same game variables at every vertical retrace.

    test_diff.py [frames] [script] [deepest]
        script: e.g. "SPACE@50-60,X@200-300" (keys held from-to frame), or random:SEED
        deepest: 1 = start in the Ancient Shrine, 2 = Crew's Quarters (via the title's debug J)
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bbcsim import BBC, KEYS  # noqa: E402
from c64sim import C64  # noqa: E402
import make_tables  # noqa: E402

# frame:address=value pokes into both machines (hex addresses and values), e.g. 260:c0=1 gives the player the passcard
POKES = [(int(f), int(a, 16), int(v, 16)) for f, rest in (p.split(":") for p in os.environ.get("DIFF_POKES", "").split(",") if p)
         for a, v in [rest.split("=")]]

ZP_MAP = {a: a for a in range(0x04, 0xd0)}
ZP_MAP.update({a: a for a in range(0xe0, 0xe4)})
ZP_MAP.update({a: a for a in (0xe8, 0xe9, 0xea, 0xec, 0xed, 0xf8, 0xf9)})
ZP_MAP.update({0x00: 0xe4, 0x01: 0xe5, 0x02: 0xe6, 0x03: 0xe7})   # the BBC's $00-$03 live at $e4-$e7


def parse_script(text):
    """'SPACE@50-60,X@200-300' -> [(key, first, last)]"""
    out = []
    for part in [p for p in (text or "").split(",") if p]:
        k, r = part.split("@")
        a, _, b = r.partition("-")
        out.append((k, int(a), int(b or int(a) + 1)))
    return out


def random_script(seed, frames, start=140, jump=False):
    """Start the game (SPACE; or J for the debug jump to a deeper level), then random key holds:
    mostly walking, with jumps, stance changes, fire."""
    import random
    r = random.Random(seed)
    out = [("J", start, start + 6)] if jump else [("SPACE", start, start + 60)]
    f = start + 80
    pool = ["X", "X", "X", "Z", "Z", "Z", ":", "/", "RETURN", "]", "A", "O", "D"]   # (not COPY: the game then waits in a tight loop for DELETE)
    while f < frames:
        n = r.choice([1, 1, 2])
        keys = r.sample(pool, n)
        d = r.randrange(3, 60)
        for k in keys:
            out.append((k, f, f + d))
        f += d + r.randrange(0, 20)
    return out


def keys_at(script, frame):
    return [k for k, a, b in script if a <= frame < b]


def main(frames=200, script_text="", deepest=0):
    if script_text.startswith("random:"):
        script = random_script(int(script_text[7:]), frames, jump=bool(deepest))
    else:
        script = parse_script(script_text)
    bbc, c64 = BBC(), C64()
    if deepest:                         # the title's debug jump: J starts in the Ancient Shrine (1) or Crew's Quarters (2)
        bbc.m[0xf9] = c64.m[0xf9] = deepest
    # the BBC game reads its OS ROM at &e400+Y for the stars; the C64 build has a table instead
    bbc.m[0xe400:0xe500] = bytes(make_tables.star_table())
    bbc.m[bbc.syms["variable_delay"]] = 0x60       # the same RTS the C64 build patches in (a busy-wait: timing only)
    snaps = {"bbc": [], "c64": []}
    seen = {"level": set(), "x": set(), "stance": set(), "screens": set()}

    def snap(who, m):
        ring = bytes(m[0x6000:0x8000])
        zp = {a: m[a if who == "bbc" else b] for a, b in ZP_MAP.items()}
        low = bytes(m[0x0100:0x01c0]) + bytes(m[0x0300:0x1100])   # (the live stack, $01c0-$01ff, is not data)
        snaps[who].append((ring, zp, low))

    bbc.trace = lambda b: snap("bbc", b.m)
    c64.on_frame = lambda c: snap("c64", c.m)
    t = time.time()
    # run both one vsync at a time, setting the keys for that frame first
    for f in range(frames):
        for pf, a, v in POKES:          # (DIFF_POKES="260:c0=1,...": the same value in both machines, to reach rare screens)
            if pf == f:
                bbc.m[a] = c64.m[a] = v
        held = keys_at(script, f)
        bbc.set_keys(*held)
        c64.held = [KEYS[k] for k in held]
        c64.apply_keys()
        bbc.run_frames(1)
        c64.run_frames(1)
        i = len(snaps["bbc"]) - 1
        m = c64.m
        seen["level"].add(m[0x9f]); seen["x"].add(m[0x93]); seen["stance"].add(m[0x6d])
        seen["screens"].add((m[0x82], m[0x83]))
        r1, z1, l1 = snaps["bbc"][i]
        r2, z2, l2 = snaps["c64"][i]
        if f % 250 == 249:
            print("  ... vsync %d ok (%.0fs)" % (f + 1, time.time() - t), file=sys.stderr, flush=True)
        problems = []
        if r1 != r2:
            diff = [k for k in range(0x2000) if r1[k] != r2[k]]
            problems.append("screen buffer: %d bytes differ, first at $%04x (cell %d)" % (len(diff), 0x6000 + diff[0], diff[0] >> 3))
        zd = [(a, z1[a], z2[a]) for a in z1 if z1[a] != z2[a]]
        if zd:
            problems.append("zero page: " + ", ".join("$%02x bbc %02x c64 %02x" % x for x in zd[:8]))
        if l1 != l2:
            d = [k for k in range(len(l1)) if l1[k] != l2[k]]
            addr = lambda k: k + 0x0100 if k < 0xc0 else k - 0xc0 + 0x0300
            problems.append("low RAM: %d bytes differ, first at $%04x (bbc %02x c64 %02x)" % (len(d), addr(d[0]), l1[d[0]], l2[d[0]]))
        if problems:
            print("DIVERGED at vsync %d" % i)
            for p in problems:
                print("  " + p)
            return 1
    if c64.port_writes:
        print("WRITES TO $00/$01 (the C64's CPU port): %s" % c64.port_writes[:3])
        return 1
    print("same screen buffer, zero page and low RAM at every one of %d vsyncs (%.1fs)" % (frames, time.time() - t))
    print("  game state covered: levels %s, player_x %d..%d, stances %s, %d distinct screen positions"
          % (sorted(seen["level"]), min(seen["x"]), max(seen["x"]), sorted(seen["stance"]), len(seen["screens"])))
    print("  stack: deepest use %d bytes (the game's data starts at $01c0 - 64 bytes available)" % (0xff - c64.min_sp))
    return 0


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 200
    sys.exit(main(n, sys.argv[2] if len(sys.argv) > 2 else "", int(sys.argv[3]) if len(sys.argv) > 3 else 0))
