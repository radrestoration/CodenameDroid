#!/usr/bin/env python3
"""The cell store stays right while the game plays: after walking (the scrolling plots columns of tiles, which are given their
characters by memo, enemy.s) and after the dirty list is processed, every ring cell's character has the cell's bytes as its
pattern and the reference counts are what the cells say.   test_cellstore.py [frames] [deepest]"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64sim import C64, RING_CELLS  # noqa: E402
from bbcsim import KEYS  # noqa: E402

RING_END = 0x8000
RING = RING_END - RING_CELLS * 8


def addrs():
    inc = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "memmap.inc")).read()
    out = {}
    for name in ("CELLCHAR", "REFL", "REFH", "BPAT0"):
        out[name] = [int(v, 16) for v in re.findall(r"^%s\s*=\s*\$([0-9a-fA-F]+)" % name, inc, flags=re.M)][-1]
    return out


def check(c, A):
    m = c.m
    refs, wrong = {}, 0
    for ci in range(RING_CELLS):
        ch = m[A["CELLCHAR"] + ci]
        refs[ch] = refs.get(ch, 0) + 1
        ring = bytes(m[RING + ci * 8:RING + ci * 8 + 8])
        pat = bytes(m[A["BPAT0"] + 0x100 * j + ch] for j in range(8))
        if ring != pat:
            wrong += 1
    wrongref = [ch for ch in range(1, 256) if refs.get(ch, 0) != (m[A["REFL"] + ch] | m[A["REFH"] + ch] << 8)]
    return wrong, wrongref


def main(frames=500, deepest=0):
    A = addrs()
    c = C64()
    if deepest:
        c.m[0xf9] = deepest
    bad = 0
    for f in range(frames):
        if deepest:
            c.held = [KEYS["J"]] if 140 <= f < 146 else ([KEYS["Z"]] if f >= 330 and (f // 120) % 2 == 0 else ([KEYS["X"]] if f >= 330 else []))
        else:
            c.held = [KEYS["SPACE"]] if 140 <= f < 200 else ([KEYS["X"]] if f >= 330 and (f // 150) % 2 == 0 else ([KEYS["Z"]] if f >= 330 else []))
        c.apply_keys()
        c.run_frames(1)
        if f > 300 and f % 40 == 0:
            c.call("mark_blasters", max_steps=500000)               # (what each frame's present does first: the blasters are not hooked)
            c.call("process_dirty", max_steps=5000000)
            wrong, wrongref = check(c, A)
            if wrong or wrongref:
                bad += 1
                print("frame %d: %d cells with the wrong pattern, %d wrong counts %s" % (f, wrong, len(wrongref), wrongref[:6]))
    print("%d frames, %d bad checks" % (frames, bad))
    print("PASS" if not bad else "FAIL")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(int(sys.argv[1]) if len(sys.argv) > 1 else 500, int(sys.argv[2]) if len(sys.argv) > 2 else 0))
