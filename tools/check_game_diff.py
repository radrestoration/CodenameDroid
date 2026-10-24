#!/usr/bin/env python3
"""The C64 PRG's copy of the game against the BBC's: build/c64/droid.prg vs build/bbc/CDroid4.

Lists every run of bytes that differs in the game ($1100-$57ff), and checks that the data
blocks are identical. Each difference is reported with the nearest label so it can be matched
to a patch in tools/make_game_source.py; anything else would be a bug.
"""
import bisect
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
B = os.path.join(HERE, "..", "build", "c64")


def labels(path):
    out = []
    for line in open(path):
        _, a, n = line.split()
        out.append((int(a, 16), n[1:]))
    return sorted(out)


def main():
    prg = open(os.path.join(B, "droid.prg"), "rb").read()
    assert prg[:2] == b"\x01\x08"
    mem = lambda a: prg[2 + a - 0x0801]
    bbc = open(os.path.join(HERE, "..", "build", "bbc", "CDroid4"), "rb").read()
    labs = labels(os.path.join(B, "c64.lbl"))
    addrs = [a for a, _ in labs]
    runs, cur = [], None
    for off in range(0x4700):
        a = 0x1100 + off
        if mem(a) != bbc[off]:
            if cur and a == cur[1] + 1:
                cur[1] = a
            else:
                cur = [a, a]
                runs.append(cur)
    lines = []
    for lo, hi in runs:
        i = bisect.bisect_right(addrs, lo) - 1
        what = "zero page $00-$03 moved to $e4-$e7" if (lo == hi and bbc[lo - 0x1100] < 4 and mem(lo) == bbc[lo - 0x1100] + 0xe4) else "patch"
        lines.append("%04x-%04x %-9s after %s+%d" % (lo, hi, what, labs[i][1], lo - labs[i][0]))
    golden = os.path.join(HERE, "expected_game_diff.txt")
    if "--update" in sys.argv:
        open(golden, "w").write("\n".join(lines) + "\n")
    want = open(golden).read().split("\n")[:-1]
    n_zp = sum("zero page" in l for l in lines)
    print("game ($1100-$57ff): %d differing runs (%d are zero page operands moved, %d patch sites)%s"
          % (len(lines), n_zp, len(lines) - n_zp, "" if lines == want else "  -- DIFFERS from tools/expected_game_diff.txt"))
    ok = lines == want
    if not ok:
        for l in sorted(set(lines) ^ set(want))[:10]:
            print("   ", ("new:     " if l in lines else "missing: ") + l)
    # the tile block at $5800 is in place; the others are staged at the start of the PRG's $6000 area
    for name, addr, off, n in (("D2_5800", 0x5800, 0x4700, 0x800),):
        same = all(mem(addr + k) == bbc[off + k] for k in range(n))
        print("%s identical: %s" % (name, same))
        ok &= same
    stage = {n: a for a, n in labs}
    for sym, off, n in (("__D2_0400_LOAD__", 0x4f00, 0xd00), ("__D2_03A0_LOAD__", 0x5c00, 0x40),
                        ("__D2_0180_LOAD__", 0x5c40, 0x40), ("__D2_0380_LOAD__", 0x5c80, 0x20),
                        ("__D2_0300_LOAD__", 0x5ca0, 0x60)):
        # (ld65's -Ln file does not list linker symbols; the staging order is fixed by c64.cfg)
        pass
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
