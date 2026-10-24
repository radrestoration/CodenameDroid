#!/usr/bin/env python3
"""How fast would the game run on a real C64 compared with the BBC? Runs both builds on the same inputs
and models the vsync waits: after each wait the next one returns at the next frame boundary after the work
done in between (BBC: 2 MHz, 50 Hz; C64: 1.023 MHz NTSC 60 Hz or 0.985 MHz PAL 50 Hz; the NTSC build also
waits an extra frame every fifth time to keep 50 Hz game speed).

    measure_speed.py [deepest]    deepest 0 = level 0 (SPACE), 1 = Ancient Shrine, 2 = Crew's Quarters"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bbcsim import BBC, KEYS  # noqa: E402
from c64sim import C64  # noqa: E402
import make_tables  # noqa: E402

BBC_FRAME = 40000          # cycles per 50 Hz frame at 2 MHz
NTSC_FRAME = 17095         # 65 cycles x 263 lines
PAL_FRAME = 19656          # 63 cycles x 312 lines


def elapsed(cycles, frame_cycles, extra_every=0):
    """frames of real time taken by a series of work intervals between vsync waits"""
    t, n = 0, 0
    for c in cycles:
        t += max(1, math.ceil(c / frame_cycles))
        n += 1
        if extra_every and n % extra_every == 0:
            t += 1
    return t


def main(deepest):
    bbc, c64 = BBC(), C64()
    bbc.m[0xe400:0xe500] = bytes(make_tables.star_table())
    if deepest:
        bbc.m[0xf9] = c64.m[0xf9] = deepest
    start = ["J", 140, 146] if deepest else ["SPACE", 140, 200]
    phases = [("idle", [], 300, 450), ("walking left (scrolling)", ["Z"], 450, 520),
              ("walking right (scrolling)", ["X"], 560, 700)]
    total = 700
    for f in range(total):
        held = [start[0]] if start[1] <= f < start[2] else []
        for name, keys, a, b in phases:
            if a <= f < b:
                held = keys
        bbc.set_keys(*held)
        c64.held = [KEYS[k] for k in held]
        c64.apply_keys()
        bbc.run_frames(1)
        c64.run_frames(1)
    print("%-28s %10s %14s %14s %14s" % ("", "BBC 50Hz", "C64 NTSC", "C64 PAL", "(frames of real time, same game progress)"))
    for name, keys, a, b in phases:
        cb, cc = bbc.frame_cycles[a:b], c64.frame_cycles[a:b]
        tb = elapsed(cb, BBC_FRAME) * 20.0
        tn = elapsed(cc, NTSC_FRAME, 5) * 1000 / 60.0
        tp = elapsed(cc, PAL_FRAME) * 20.0
        print("%-28s %8.0fms %8.0fms (%3.0f%%) %8.0fms (%3.0f%%)   over %d vsync waits"
              % (name, tb, tn, 100 * tn / tb, tp, 100 * tp / tb, b - a))


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else 0)
