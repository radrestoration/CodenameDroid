#!/usr/bin/env python3
"""Check the built files.

    check_build.py LISTING BUILD_DIR [DISC.ssd]

For whichever of build/CDroid4 (disc release) and build/DROID + DROID2
(tape release) exist:

  - the game and the data blocks must equal the listing's hex bytes (the
    tape release is what the listing is), except for the bytes recorded in
    droidlist.KNOWN_DISC_DIFFS, where the source has the disc's value;
  - every label of the listing (but the tape-only ones, for the disc
    release) must be at the address the listing gives;
  - with the disc image: CDroid4 must equal the file of that name on it,
    byte for byte, all &5e00 of them.
"""
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from droidlist import (D2_BLOCKS, KNOWN_DISC_DIFFS, Listing,  # noqa: E402
                       d2_file_offset)

GAME_LEN = 0x4700                       # &1100-&57ff
# offsets of DROID2's blocks in CDroid4, from GAME_LEN
DISC_D2_OFFSET = {0x5800: 0x0000, 0x0400: 0x0800, 0x03a0: 0x1500,
                  0x0180: 0x1540, 0x0380: 0x1580, 0x0300: 0x15a0}


def dfs_file(disc, name):
    cat0, cat1 = disc[:256], disc[256:512]
    for i in range(cat1[5] // 8):
        e, m = cat0[8 + 8 * i:16 + 8 * i], cat1[8 + 8 * i:16 + 8 * i]
        if e[:7].decode("latin1").rstrip() == name:
            length = m[4] | m[5] << 8 | ((m[6] >> 4) & 3) << 16
            sector = m[7] | (m[6] & 3) << 8
            return disc[sector * 256:sector * 256 + length]
    raise SystemExit("no file %s on the disc" % name)


def tape_only(sec, addr):
    return (sec == "DROID" and addr >= 0x5800) or (sec == "DROID2" and addr >= 0x7b00)


def check_labels(listing, lbl, skip_tape_only):
    built = collections.defaultdict(set)
    for line in open(lbl):
        _, addr, name = line.split()
        built[name[1:]].add(int(addr, 16))
    labs = Listing(listing).labels()
    count = collections.Counter(n for n, _, _ in labs)
    wrong, n = [], 0
    for nm, addr, sec in labs:
        if skip_tape_only and tape_only(sec, addr):
            continue
        n += 1
        want = nm if count[nm] == 1 else "%s_%04x" % (nm, addr)
        if addr not in built.get(want, ()):
            wrong.append((want, addr, sorted(built.get(want, ()))))
    print("  labels: %d checked, %d not at the listed address" % (n, len(wrong)))
    for w in wrong[:10]:
        print("     %s expected %04x, built %s" % (w[0], w[1], [hex(x) for x in w[2]]))
    return not wrong


def main():
    listing, build = sys.argv[1], sys.argv[2]
    disc = open(sys.argv[3], "rb").read() if len(sys.argv) > 3 else None
    img = Listing(listing).images()
    want_game = dict(img["DROID"])
    for a, (_, disc_v, _) in KNOWN_DISC_DIFFS.items():
        want_game[a] = disc_v
    ok, did = True, False

    p = os.path.join(build, "CDroid4")
    if os.path.exists(p):
        did = True
        f = open(p, "rb").read()
        print("disc release (CDroid4, %d bytes):" % len(f))
        if len(f) != 0x5e00:
            print("  FAIL: expected %d bytes" % 0x5e00)
            return 1
        bad = [a for a in range(0x1100, 0x5800) if f[a - 0x1100] != want_game.get(a)]
        for first, last, _ in D2_BLOCKS[:-1]:
            for a in range(first, last + 1):
                if f[GAME_LEN + DISC_D2_OFFSET[first] + a - first] != img["DROID2"].get(a):
                    bad.append(a)
        print("  game and data blocks: %d bytes, %d differ from the listing"
              % (0x4700 + sum(l - f_ + 1 for f_, l, _ in D2_BLOCKS[:-1]), len(bad)))
        ok &= not bad
        if os.path.exists(os.path.join(build, "disc.lbl")):
            ok &= check_labels(listing, os.path.join(build, "disc.lbl"), True)
        if disc:
            theirs = dfs_file(disc, "CDroid4")
            diffs = [a for a in range(0x5e00) if f[a] != theirs[a]]
            print("  against the file on the disc: %d of %d bytes differ" % (len(diffs), len(theirs)))
            for a in diffs[:10]:
                print("     %04x built %02x disc %02x" % (0x1100 + a, f[a], theirs[a]))
            ok &= not diffs and len(theirs) == len(f)

    pa, pb = os.path.join(build, "DROID"), os.path.join(build, "DROID2")
    if os.path.exists(pa) and os.path.exists(pb):
        did = True
        d1, d2 = open(pa, "rb").read(), open(pb, "rb").read()
        print("tape release (DROID %d bytes, DROID2 %d bytes):" % (len(d1), len(d2)))
        if (len(d1), len(d2)) != (0x4800, 0x1700):
            print("  FAIL: sizes")
            return 1
        bad = [a for a in range(0x1100, 0x5900) if d1[a - 0x1100] != want_game.get(a)]
        bad2 = [a for first, last, _ in D2_BLOCKS for a in range(first, last + 1)
                if d2[d2_file_offset(a)] != img["DROID2"].get(a)]
        print("  DROID: %d differ from the listing; DROID2: %d" % (len(bad), len(bad2)))
        ok &= not bad and not bad2
        if os.path.exists(os.path.join(build, "tape.lbl")):
            ok &= check_labels(listing, os.path.join(build, "tape.lbl"), False)
    if not did:
        print("nothing built")
        return 1
    print("OK" if ok else "FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    sys.exit(main())
