#!/usr/bin/env python3
"""Compare the ring of the 40-column build with the BBC's, cell by cell in window coordinates (columns 0-31 of the wide
window against the BBC's 32), at a vsync after the same keys.   cmp_wide.py FRAME [SCRIPT]   -> prints a map of the
differing cells (# = differs)."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from bbcsim import BBC, KEYS  # noqa: E402
from c64sim import C64, RING, RING_W, RING_CELLS  # noqa: E402
import make_tables  # noqa: E402
import test_diff  # noqa: E402


def main(frames, script_text, dx=0):
    script = test_diff.parse_script(script_text) if script_text else []
    bbc, c64 = BBC(), C64()
    bbc.m[0xe400:0xe500] = bytes(make_tables.star_table())
    bbc.m[bbc.syms["variable_delay"]] = 0x60
    for f in range(frames):
        held = test_diff.keys_at(script, f)
        bbc.set_keys(*held)
        c64.held = [KEYS[k] for k in held]
        c64.apply_keys()
        bbc.run_frames(1)
        c64.run_frames(1)
    sb = ((bbc.screen_start() - 0x6000) >> 3) & 1023
    sc = ((c64.m[0x200] - (RING >> 11)) << 8) | c64.m[0x201]
    print("S: bbc %d c64 %d (c64 level %d x %d, bbc level %d x %d)" % (sb, sc, c64.m[0x9f], c64.m[0x93], bbc.m[0x9f], bbc.m[0x93]))
    diff = 0
    for r in range(32):
        row = ""
        for c in range(32):
            ib = (sb + 32 * r + c) % 1024
            ic = (sc + RING_W * r + c + dx) % RING_CELLS
            cb = bytes(bbc.m[0x6000 + ib * 8:0x6000 + ib * 8 + 8])
            cc = bytes(c64.m[RING + ic * 8:RING + ic * 8 + 8])
            if cb != cc:
                row += "#"
                diff += 1
            else:
                row += "." if any(cb) else " "
        print("%2d %s" % (r, row))
    print("cells differing: %d" % diff)


if __name__ == "__main__":
    main(int(sys.argv[1]), sys.argv[2] if len(sys.argv) > 2 else "", int(sys.argv[3]) if len(sys.argv) > 3 else 0)
