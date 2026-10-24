#!/usr/bin/env python3
"""The tables the C64 makes at start-up (make_runtime_tables in platform.s) against make_tables.py's, and that hash_tab is a
permutation.   test_tables.py"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64sim import C64  # noqa: E402
import make_tables  # noqa: E402


def main():
    c = C64()
    c.call("make_runtime_tables", max_steps=2000000)
    s = c.syms
    ok = True
    for name, want in (("bbc_to_c64", make_tables.bbc_to_c64_table()), ("chandelier_class", make_tables.chandelier_class_table()),
                       ("hash_tab", make_tables.hash_tab_table()),
                       ("star_random", make_tables.star_table())):
        got = list(c.m[s[name]:s[name] + 256])
        good = got == want
        ok &= good
        print("%s %s" % ("ok " if good else "BAD", name))
    perm = sorted(c.m[s["hash_tab"]:s["hash_tab"] + 256]) == list(range(256))
    ok &= perm
    print("%s hash_tab is a permutation" % ("ok " if perm else "BAD"))
    print("PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
