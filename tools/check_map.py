#!/usr/bin/env python3
"""The link map's checks: what the game needs while it runs must end below $a000 (the character set and screen matrices
are there from start-up on), and the loading screens' data below $d000.   check_map.py c64.map"""
import re
import sys

LIVE = ("DROID", "D2_5800", "START", "CODE")           # (SOUNDC runs elsewhere)


def main(path):
    seg = {}
    for line in open(path):
        m = re.match(r"^([A-Z0-9_]+)\s+([0-9A-F]{6})\s+([0-9A-F]{6})\s+([0-9A-F]{6})", line)
        if m:
            seg[m.group(1)] = (int(m.group(2), 16), int(m.group(3), 16), int(m.group(4), 16))
    bad = []
    for n in LIVE:
        if n in seg and seg[n][2] and seg[n][1] >= 0xa000:
            bad.append("%s ends at $%04x (must be below $a000)" % (n, seg[n][1]))
    for n in ("RODATA", "INTRO", "INTRO2", "SOUNDC"):
        if n in seg and seg[n][2]:
            lo, hi = seg[n][0], seg[n][1]
            load_hi = hi if n not in ("SOUNDC",) else None
            if load_hi is not None and load_hi >= 0xd000:
                bad.append("%s ends at $%04x (must be below $d000)" % (n, hi))
    room = 0x9fff - seg["CODE"][1]
    if bad:
        print("\n".join(bad))
        return 1
    print("link map ok: the game's code ends at $%04x (%d bytes below $a000 to spare)" % (seg["CODE"][1], room))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
