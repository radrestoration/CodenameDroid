#!/usr/bin/env python3
"""Unit test of the C64 keyboard/joystick scan: the real scan code runs in the simulator against a
model of CIA 1; after each frame $ed (oldest key held) and $ec (newest) must be what the BBC's OS
would have left for the same keys."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64sim import C64  # noqa: E402

KEY = {"Z": (1, 4), "X": (2, 7), "=": (6, 5), "/": (6, 7), "RETURN": (0, 1), ";": (6, 2),
       "SPACE": (7, 4), "A": (1, 2), "S": (1, 5), "D": (2, 2), "P": (0 + 5, 1), "CTRL": (7, 2)}
BBC = {"Z": 0xe1, "X": 0xc2, ";": 0xc8, "/": 0xe8, "RETURN": 0xc9, "=": 0xd8, "SPACE": 0xe2,
       "A": 0xc1, "D": 0xb2, "P": 0xe9, "CTRL": 0xe0}


def main():
    c = C64(scan="real")
    c.irq_every = 0                 # one scan per frame, called by the harness, so each step is exactly one scan
    c.run_frames(3)
    steps = [
        ([], [], (0, 0)),
        (["Z"], [], (0xe1, 0xe1)),
        (["Z", "RETURN"], [], (0xe1, 0xc9)),            # jump while walking left: Z oldest, RETURN newest
        (["Z", "RETURN", "X"], [], (0xe1, 0xc2)),
        (["RETURN", "X"], [], (0xc9, 0xc2)),            # Z released: RETURN is now the oldest
        ([], ["left"], (0xe1, 0xe1)),                   # joystick left = Z
        ([], ["left", "fire"], (0xe1, 0xc9)),
        ([], ["up"], (0xc8, 0xc8)),
        (["Z"], ["left"], (0xe1, 0xe1)),                # the same key from keyboard and joystick counts once
        (["=", "D"], [], (0xd8, 0xb2)),                 # the blaster key and a mine
        ([";"], [], (0xc8, 0xc8)),                      # up
        (["/"], [], (0xe8, 0xe8)),                      # down
        (["P"], [], (0xe9, 0xe9)),
        (["CTRL", "SPACE"], [], (0xe2, 0xe0)),     # pressed in the same scan: ordered by the key table
        ([], [], (0, 0)),
    ]
    bits = {"up": 0, "down": 1, "left": 2, "right": 3, "fire": 4}
    ok = True
    for keys, joy, want in steps:
        c.pressed = {KEY[k] for k in keys}
        c.joy = 0x1f
        for j in joy:
            c.joy &= ~(1 << bits[j])
        c.run_frames(1)
        got = (c.m[0xed], c.m[0xec])
        flag = "ok " if got == want else "BAD"
        ok &= got == want
        print("%s keys %-22s joy %-14s -> $ed $ec = %02x %02x (want %02x %02x)" % (flag, keys, joy, got[0], got[1], want[0], want[1]))
    # ASCII for the terminal: the first newly pressed key, latched in kb_ascii until read (as c64_osrdch does)
    c.pressed = set()
    c.run_frames(1)
    c.m[0x024a] = 0
    c.pressed = {KEY["S"]}
    c.run_frames(1)
    a = c.m[0x024a]
    print("%s S newly pressed -> kb_ascii %r" % ("ok " if a == ord("S") else "BAD", chr(a)))
    ok &= a == ord("S")
    c.m[0x024a] = 0                         # the reader takes it
    c.run_frames(1)
    a = c.m[0x024a]
    print("%s S still held -> kb_ascii %d (want 0)" % ("ok " if a == 0 else "BAD", a))
    ok &= a == 0
    print("PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
