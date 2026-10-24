#!/usr/bin/env python3
"""Unit test of the vertical camera (cells.s camera_update): player placed at displayed rows, camera
stepped a row at a time; checks the limits and the drift back to the default view."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64sim import C64, RING, RING_W, RING_CELLS, CRTC_BASE  # noqa: E402


def settle(c, row, line=0, S=0, cam=4, n=12, game=1, title=0):
    m = c.m
    m[0x0207] = game
    m[0x020f] = title
    m[0x0200], m[0x0201] = CRTC_BASE + (S >> 8), S & 255
    ci = (S + RING_W * row) % RING_CELLS            # the player's top-left cell
    addr = RING + ci * 8 + line
    m[0x90], m[0x91] = addr & 255, addr >> 8
    m[0x0203] = cam
    seq = [cam]
    for _ in range(n):
        c.call("camera_update")
        seq.append(m[0x0203])
    return seq


def main():
    c = C64()
    c.call("cells_init", max_steps=2_000_000)       # (the wide ring's row table)
    ok = True

    def expect(name, seq, final, steps=True):
        nonlocal ok
        good = seq[-1] == final and (not steps or all(abs(a - b) <= 1 for a, b in zip(seq, seq[1:])))
        ok &= good
        print("%s %-52s cam %s -> %d (want %d)" % ("ok " if good else "BAD", name, seq[0], seq[-1], final))
    expect("standing on the floor (row 24), default camera", settle(c, 24), 4)
    expect("player on the top tile row (row 4)", settle(c, 4), 2)
    expect("player at the very top (row 0)", settle(c, 0), 0)
    expect("player in the floor row (row 28): camera down", settle(c, 28), 7)
    expect("... then back on the floor (row 24): drifts to 4", settle(c, 24, cam=7), 4)
    expect("... high up (row 8) with cam 0: drifts back to 4", settle(c, 8, cam=0), 4)
    expect("half-cell offset (line 4) at row 24", settle(c, 24, line=4), 4)
    expect("display scrolled: S = 300, player at row 24", settle(c, 24, S=300), 4)
    expect("title screen: cam 4", settle(c, 0, cam=1, game=0, title=1), 4, steps=False)
    expect("not in gameplay (status screen): cam forced to 4", settle(c, 0, cam=1, game=0), 4, steps=False)       # (snaps: those screens redraw anyway)
    print("PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
