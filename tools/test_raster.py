#!/usr/bin/env python3
"""The C64 build with the real raster-wait code and the asynchronous raster interrupt (c64raster.py), PAL and NTSC:
the title scroll must finish (the game once froze here: waiting for raster line $fc while the interrupt at $fb
ran past it), the display must then show the buffer, SPACE must start the game, and walking right must scroll.
While a matrix is shown only single cells may be written to it (the rebuild after a scroll goes to the other one,
which the interrupt swaps in between frames: no tearing).   test_raster.py"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64raster import C64Raster  # noqa: E402
from c64sim import RING_W, RING_CELLS, CRTC_BASE  # noqa: E402


def S(c):
    return c.m[0x201] | (c.m[0x200] - CRTC_BASE) << 8


def mismatches(c):
    vb = c.m[0xda] | c.m[0xdb] << 8
    mp = c.matrix_pixels()
    bad = 0
    if c.m[0x22c] == 1:                         # the title shown through its map (40 cells: tools/make_title_map.py)
        import make_title_map
        fw = make_title_map.forward()
        for cell, off in fw.items():
            r, col = divmod(cell, 40)
            exp = c.ring_cell_pixels((vb + off) % RING_CELLS)
            if not (exp == mp[r * 8:r * 8 + 8, col * 4:col * 4 + 4]).all():
                bad += 1
        return bad
    for r in range(25):
        for col in range(len(mp[0]) // 4):
            exp = c.ring_cell_pixels((vb + RING_W * r + col) % RING_CELLS)
            if not (exp == mp[r * 8:r * 8 + 8, col * 4:col * 4 + 4]).all():
                bad += 1
    return bad


def run(pal):
    name = "PAL" if pal else "NTSC"
    c = C64Raster(pal=pal)
    shown = [0, 0]                      # writes into the shown matrix since the last interrupt, and the most in one frame
    worst = []

    def watch(addr, val):
        base = 0x8000 + ((c.m[0xd018] >> 4) & 15) * 0x400     # the matrix $d018 selects (what the VIC-II reads)
        if base <= addr < base + 1000:
            shown[0] += 1
            shown[1] = max(shown[1], shown[0])
    c.cpu.write_hooks.append(watch)

    def after(cc):
        worst.append(mismatches(cc))
    c.after_present = after
    done = None
    for f in range(700):
        c.run_frames(1)
        shown[0] = 0                    # (an interrupt ends the frame)
        if done is None and c.m[0x9f] == 0 and S(c) == 140:
            done = f
            break
    assert done is not None, "%s: the title scroll never finished (S=%d level=%d)" % (name, S(c), c.m[0x9f])
    worst.clear()
    for _ in range(30):
        c.run_frames(1)
        shown[0] = 0
    assert max(worst) == 0, "%s: up to %d cells of the title display differ from the buffer" % (name, max(worst))
    c.pressed = {(7, 4)}                      # SPACE
    c.run_frames(40)
    c.pressed = set()
    c.run_frames(200)
    assert c.m[0x207] == 1, "%s: SPACE did not start the game (mode %d)" % (name, c.m[0x207])
    s0 = S(c)
    c.pressed = {(2, 7)}                      # X: walk right
    worst.clear()
    shown[1] = 0
    for _ in range(100):
        c.run_frames(1)
        shown[0] = 0
    moved = (S(c) - s0) & 1023
    print("%s: title scroll done at frame %d; game started; walking right scrolled %d cells in 100 frames (the BBC: 23 "
          "at 50 Hz); most cells differing from the buffer after a display update: %d; most writes into the shown "
          "matrix in a frame: %d (rebuilding it would be 800)" % (name, done, moved, max(worst), shown[1]))
    assert moved >= 8, "%s: walking right scrolled only %d cells in 100 frames" % (name, moved)
    assert max(worst) == 0, "%s: the display differs from the buffer" % name
    assert shown[1] < 300, "%s: the shown matrix is rebuilt in place (tearing)" % name


if __name__ == "__main__":
    run(True)
    run(False)
    print("PASS")
