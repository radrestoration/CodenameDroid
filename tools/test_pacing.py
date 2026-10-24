#!/usr/bin/env python3
"""The NTSC pacing in hw_wait_frame, run for real against a model of the raster beam: with different amounts of game
work between waits, how many frames pass per wait?  (50 Hz game on a 60 Hz machine: 1.2 when the work is light;
no extra waiting when the game is already late; PAL: always 1.)"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64sim import C64  # noqa: E402

LINE, LINES = 65, 263                         # NTSC: cycles per raster line, lines per frame
FRAME = LINE * LINES


def run(work, waits=200, pal=0):
    c = C64()
    cpu, m = c.cpu, c.m
    del cpu.traps[c.syms["hw_wait_frame"]]    # run the real routine, not the trap
    m[0x205] = pal
    m[0x209] = 32                             # c64_acc
    m[0x208] = 0                              # c64_lastf
    m[0x206] = 0                              # c64_frames
    frame_len = 63 * 312 if pal else FRAME
    lines = 312 if pal else LINES
    cyc_line = 63 if pal else LINE
    start = cpu.cycles
    frames_seen = [0]

    def beam():
        t = cpu.cycles - start
        line = (t // cyc_line) % lines
        m[0xd012] = line & 255
        f = t // frame_len + (1 if line >= 0xfb else 0)       # the raster interrupt at $fb has fired this many times
        m[0x206] = f & 255
        return f
    waits_done = 0
    total_frames_before = None
    ret = 0xfff0
    for _ in range(waits):
        cpu.cycles += work                    # the game's own work
        beam()
        cpu.push(((ret - 1) >> 8) & 255)
        cpu.push((ret - 1) & 255)
        cpu.pc = c.syms["hw_wait_frame"]
        n = 0
        while cpu.pc != ret:
            beam()
            cpu.step()
            n += 1
            assert n < 5_000_000, "hw_wait_frame did not return"
    return (cpu.cycles - start) / frame_len / waits


def main():
    ok = True
    # a wait takes the longer of a 50 Hz step (1.2 NTSC frames, 1 PAL frame) and the game's own work: a game that is
    # late does not idle until the next frame boundary (the picture is double buffered, so no tearing needs that)
    for name, work, pal, lo, hi in (("light work (3000 cycles)", 3000, 0, 1.19, 1.21),
                                    ("work just over a frame (19000)", 19000, 0, 1.19, 1.21),
                                    ("work of 1.5 frames (25000)", 25000, 0, 1.45, 1.50),
                                    ("heavy (40000)", 40000, 0, 2.30, 2.40),
                                    ("light work, PAL", 3000, 1, 0.99, 1.01),
                                    ("work of 1.27 frames, PAL (25000)", 25000, 1, 1.25, 1.30),
                                    ("heavy, PAL (60000)", 60000, 1, 3.0, 3.1)):
        r = run(work, pal=pal)
        good = lo <= r <= hi
        ok &= good
        print("%s %-34s %.3f frames per wait (want %.2f-%.2f)" % ("ok " if good else "BAD", name, r, lo, hi))
    print("PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
