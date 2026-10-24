#!/usr/bin/env python3
"""The title screen's map (tools/make_title_map.py, src/cells.s title_remap): the table is unpacked into memory right; once
the title's scroll is over the matrix shows the ring through it, cell for cell, and goes on doing so as the title animates;
SPACE puts the ordinary view back.   Only for the 40-column build."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64sim import C64, RING_W  # noqa: E402
import make_title_map  # noqa: E402

CELLCHAR, TMAP_SEG, TMAP, TMAP_OK = 0xb000, 0xfe00, 0x22c, 0x22d
fails = []


def check(ok, what):
    print("%s %s" % ("ok " if ok else "BAD", what))
    if not ok:
        fails.append(what)


def mismatches(c):
    """Matrix cells (of the one shown) that are not the character of the ring cell the map says they show."""
    fw = make_title_map.forward()
    vb = c.m[0xda] | c.m[0xdb] << 8
    base = c.display_base()
    bad = []
    for cell, off in fw.items():
        want = c.m[CELLCHAR + (vb + off) % (RING_W * 32)]
        if c.m[base + cell] != want:
            bad.append(cell)
    return bad


def main():
    if RING_W != 40:
        print("not the 40-column build: nothing to test")
        return 0
    c = C64()
    want = make_title_map.tables()
    c.run_frames(5)
    check(c.m[TMAP_OK] == 1 and bytes(c.m[TMAP_SEG:TMAP_SEG + len(want)]) == want, "the map is unpacked into memory")
    n = 0
    hidden_from, shown_with_old = None, 0
    while c.m[TMAP] != 1 and n < 1500:
        c.run_frames(1)
        n += 1
        count = c.m[0x90]                                    # (the scroll's steps left)
        den = c.m[0xd011] & 0x10
        if not den and hidden_from is None:
            hidden_from = count
        if count and count <= 33 and den:
            shown_with_old += 1                              # (the old frame sliding in must not be on the screen)
    check(c.m[TMAP] == 1, "the title screen is shown through the map once it is still (frame %d)" % n)
    check(hidden_from is not None and 30 <= hidden_from <= 34 and shown_with_old == 0,
          "the screen is blanked for the scroll's last steps (from %s steps left; %d frames with the old frame showing)" % (hidden_from, shown_with_old))
    c.run_frames(3)
    check(c.m[0xd011] & 0x10 != 0, "and on again for the title")
    bad = mismatches(c)
    check(not bad, "the matrix is the ring seen through the map (%d cells differ)" % len(bad))
    worst, frames = 0, 0
    for _ in range(120):                                     # the player runs, a blaster flies
        c.run_frames(1)
        frames += 1
        worst = max(worst, len(mismatches(c)))
    check(worst == 0, "it stays so as the title animates (%d frames, at most %d cells differ)" % (frames, worst))
    # the frame is wider and shorter: a few spot checks of the layout (screen cell -> ring cell)
    fw = make_title_map.forward()
    check(fw[4] // 40 in (0, 1, 2, 3) and fw[0] // 40 == fw[4] // 40, "the top bar's extra squares are bar squares")
    print("PASS" if not fails else "FAIL: %d" % len(fails))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
