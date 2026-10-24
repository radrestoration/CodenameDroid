#!/usr/bin/env python3
"""The C64 display over randomised play: the matrix always matches the screen buffer, the camera stays in
range, and in gameplay the player's rows are on screen.   test_view.py SEED FRAMES [deepest]"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bbcsim import KEYS  # noqa: E402
from c64sim import C64, RING, RING_W, RING_CELLS, CRTC_BASE  # noqa: E402
import test_diff  # noqa: E402
import test_c64  # noqa: E402


def main(seed, frames, deepest=0):
    script = test_diff.random_script(seed, frames, jump=bool(deepest))
    c = C64()
    if deepest:
        c.m[0xf9] = deepest
    cams, bad, hidden = set(), [], []

    def check(c):
        m = c.m
        cams.add(m[0x0203])
        if c.frames % 4 == 0:
            b1, b2 = test_c64.cell_store_ok(c), test_c64.matrix_ok(c)
            if b1 or b2:
                bad.append((c.frames, b1[:2], b2[:2]))
        if m[0x0207] and c.frames > 250:
            # player's top row on screen relative to the view
            S = ((m[0x0200] - CRTC_BASE) << 8) | m[0x0201]
            ci = (((m[0x91] << 8 | m[0x90]) - RING) >> 3) % RING_CELLS
            row = (((ci - S) % RING_CELLS) // RING_W) - m[0x0203]
            if not (0 <= row and row + 3 <= 24):
                hidden.append((c.frames, row, m[0x0203]))
    c.after_present = check
    for f in range(frames):
        c.held = [KEYS[k] for k in test_diff.keys_at(script, f)]
        c.apply_keys()
        c.run_frames(1)
    print("seed %d: %d frames; camera values seen %s; matrix/cell-store failures %d; frames with the player partly off screen %d"
          % (seed, frames, sorted(cams), len(bad), len(hidden)))
    for x in bad[:3]:
        print("  invariant", x)
    for x in hidden[:5]:
        print("  off screen: frame %d row %d cam %d" % x)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3]) if len(sys.argv) > 3 else 0))
