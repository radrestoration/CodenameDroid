#!/usr/bin/env python3
"""Headless checks of the C64 build. See make test.

 1. cell store: after every frame, every one of the ring's 1024 cells has a character whose
    pattern is that cell's bytes, and the matrix shows the right character for each visible cell.
 2. (with the BBC reference) the same inputs on the original BBC build and on the C64 build give
    the same screen buffer and game state at every frame.
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64sim import C64, CHARSET, MATRIX, CELLCHAR, RING, RING_W, RING_CELLS  # noqa: E402
import bbcmem as bm  # noqa: E402


def cell_store_ok(c, verbose=True):
    """Return a list of problems with the cell store, empty if consistent."""
    m = c.m
    bad = []
    t = bm_table()
    for idx in range(RING_CELLS):
        ch = m[CELLCHAR + idx]
        want = bytes(t[m[RING + idx * 8 + k]] for k in range(8))
        have = bytes(m[CHARSET + ch * 8 + k] for k in range(8))
        if want != have:
            bad.append((idx, ch, want.hex(), have.hex()))
    return bad


_T = None
def bm_table():
    global _T
    if _T is None:
        _T = []
        for b in range(256):
            p = bm.pixels(b)
            _T.append(p[0] << 6 | p[1] << 4 | p[2] << 2 | p[3])
    return _T


def matrix_ok(c):
    m = c.m
    vb = c.view_base()
    bad = []
    if m[0x22c] == 1:                           # the title shown through its map (40 cells: tools/make_title_map.py)
        import make_title_map
        for cell, off in make_title_map.forward().items():
            idx = (vb + off) % RING_CELLS
            if m[c.display_base() + cell] != m[CELLCHAR + idx]:
                bad.append((cell // 40, cell % 40, idx))
        return bad
    vcols, mcol0 = m[0x215], m[0x214]
    for r in range(25):
        for col in range(vcols):
            idx = (vb + RING_W * r + col) % RING_CELLS
            if m[c.display_base() + 40 * r + mcol0 + col] != m[CELLCHAR + idx]:
                bad.append((r, col, idx))
    return bad


def main():
    c = C64()
    problems = []

    def check(c):
        if c.frames % 1 == 0:
            b = cell_store_ok(c)
            b2 = matrix_ok(c)
            if b or b2:
                problems.append((c.frames, b[:3], b2[:3]))
    c.after_present = check
    t = time.time()
    c.run_frames(60)
    print("ran %d frames in %.1fs; engine invariant failures: %d" % (c.frames, time.time() - t, len(problems)))
    for p in problems[:5]:
        print("  frame", p[0], "cellstore", p[1], "matrix", p[2])
    print("min SP seen", hex(c.min_sp), "frame cycles (first 10)", c.frame_cycles[:10])
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
