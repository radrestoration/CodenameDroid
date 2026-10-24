#!/usr/bin/env python3
"""While the title scrolls right a cell a frame, each displayed frame must be the previous one moved a column
(or two, when every other step is shown) left, plus the entering column at the right (a column drawn ahead of the display start must never show at the
left: the BBC's CRTC applies the new start address together with it).   test_scroll.py"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64sim import C64  # noqa: E402


MATRIX = 0xa800


def main():
    c = C64(scan="real")
    shots = []

    def grab(c):
        vb = c.m[0xda] | c.m[0xdb] << 8
        base = c.display_base()
        col0, cols = c.m[0x214], c.m[0x215]
        rows = [bytes(c.m[base + 40 * r + col0:base + 40 * r + col0 + cols]) for r in range(25)]
        shots.append((vb, rows))
    c.after_present = grab
    c.run_frames(150)
    steps = bad = 0
    for (v0, a), (v1, b) in zip(shots, shots[1:]):
        d = (v1 - v0) & 1023
        if d not in (1, 2):             # (the title is shown every other step: two cells at a time)
            continue
        steps += 1
        if any(a[r][d:] != b[r][:len(b[r]) - d] for r in range(25)):
            bad += 1
    print("scroll steps: %d, frames where the picture was not the last one shifted a column: %d" % (steps, bad))
    assert steps > 60, "no scroll seen"
    assert bad == 0
    print("PASS")


if __name__ == "__main__":
    main()
