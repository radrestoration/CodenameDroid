#!/usr/bin/env python3
"""The enemies' fast plots keep the cell store right: after random plots through the game's own entries (plot_sprite and
plot_flipped_enemy, with their hooks), at random cells of the ring, every cell's character has the cell's bytes as its pattern,
and the reference counts are what the cells say.   test_enemycells.py [plots]"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64sim import C64, RING_W, RING_CELLS  # noqa: E402
import wide_patches  # noqa: E402

RING_END = 0x8000
RING = RING_END - RING_CELLS * 8


def check(c, label):
    m = c.m
    S = c.syms
    CELLCHAR, BPAT0, REFL, REFH = (wide_patches.SYMS[n] if n in wide_patches.SYMS else None for n in ("CELLCHAR", "BPAT0", "REFL", "REFH"))
    return None


def main(n=150):
    c = C64()
    c.run_frames(3)
    m = c.m
    import re
    inc = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "memmap.inc")).read()
    sym = {}
    for name, val in re.findall(r"^(\w+)\s*=\s*\$([0-9a-fA-F]+)", inc, flags=re.M):
        sym.setdefault(name, int(val, 16))
    # (the 40-column layout's addresses are the ones after ".else": setdefault keeps the first, so read both)
    for name in ("CELLCHAR", "REFL", "REFH", "BPAT0"):
        vals = [int(v, 16) for v in re.findall(r"^%s\s*=\s*\$([0-9a-fA-F]+)" % name, inc, flags=re.M)]
        sym[name] = vals[-1] if RING_W != 32 else vals[0]
    rnd = random.Random(5)
    c.call("process_dirty", max_steps=5000000)
    bad = 0
    for k in range(n):
        flipped = k & 1
        h = rnd.choice((8, 16, 24, 32, 32, 32))
        sa = RING + rnd.randrange(0, RING_CELLS - 40) * 8
        if k % 4 == 0:
            sa = RING_END - rnd.randint(1, 60) * 8                          # (round the end of the ring)
        spr = 0x0a00 + 8 * rnd.randrange(0, 40) if k % 3 else 0x0a00 + 8 * rnd.randrange(0, 6)   # (the enemies' sprites, few sources: the memo is used)
        if k % 25 == 24:                                            # (the game rewrites them in place: swap_enemy_colours, which forgets)
            for a in range(0x0a00, 0x0b40):
                m[a] ^= 0x35
            c.call("c64_swap_hook", max_steps=500000)
        m[0x70], m[0x71] = sa & 255, sa >> 8
        m[0x72], m[0x73] = spr & 255, spr >> 8
        m[0x78] = 0
        c.cpu.x, c.cpu.y = 3, h
        c.call("plot_flipped_enemy" if flipped else "plot_sprite", max_steps=2000000)
        if k % 5 == 4:
            c.call("process_dirty", max_steps=5000000)
            # every cell's pattern
            refs = {}
            wrong = 0
            for ci in range(RING_CELLS):
                ch = m[sym["CELLCHAR"] + ci]
                refs[ch] = refs.get(ch, 0) + 1
                ring = bytes(m[RING + ci * 8:RING + ci * 8 + 8])
                pat = bytes(m[sym["BPAT0"] + 0x100 * j + ch] for j in range(8))
                if ring != pat:
                    wrong += 1
            wrongref = [ch for ch in range(1, 256) if refs.get(ch, 0) != (m[sym["REFL"] + ch] | m[sym["REFH"] + ch] << 8)]
            if wrong or wrongref:
                bad += 1
                if bad <= 5:
                    print("after plot %d (%s h=%d at %04x from %04x): %d cells with the wrong pattern, %d wrong counts %s"
                          % (k, "flipped" if flipped else "plain", h, sa, spr, wrong, len(wrongref), wrongref[:6]))
    print("%d plots, %d bad checks" % (n, bad))
    print("PASS" if not bad else "FAIL")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(int(sys.argv[1]) if len(sys.argv) > 1 else 150))
