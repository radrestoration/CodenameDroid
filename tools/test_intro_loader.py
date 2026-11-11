#!/usr/bin/env python3
"""Check the relocated intro loader's KERNAL calls and failure handling."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sim6502 import CPU
from sim_check import labels


def check(build, error):
    symbols = labels(os.path.join(build, "intro.lbl"))
    intro = open(os.path.join(build, "intro.prg"), "rb").read()
    game = open(os.path.join(build, "game.prg"), "rb").read()
    address = intro[0] | intro[1] << 8
    cpu = CPU()
    cpu.m[address:address + len(intro) - 2] = intro[2:]
    first, end = symbols["loader_src"], symbols["loader_end"]
    assert 0 < end - first <= 128
    cpu.m[0x334:0x334 + end - first] = cpu.m[first:end]
    cpu.pc = 0x335
    calls = []

    def setnam(c):
        name = bytes(c.m[(c.y << 8 | c.x):(c.y << 8 | c.x) + c.a])
        calls.append(("name", name))

    def setlfs(c):
        calls.append(("file", c.a, c.x, c.y))

    def load(c):
        calls.append(("load", c.a))
        c.c = int(error is not None)
        if error is not None:
            c.a = error
        else:
            start = game[0] | game[1] << 8
            c.m[start:start + len(game) - 2] = game[2:]

    cpu.traps.update({0xffbd: setnam, 0xffba: setlfs, 0xffd5: load})
    for _ in range(1000):
        if cpu.pc == 0x0810:
            assert error is None, "failed load restarted the intro"
            break
        cpu.step()
    else:
        assert error is not None, "successful load did not enter the game"
        assert cpu.m[0x0400:0x0408] == bytes((12, 15, 1, 4, 32, 7, 1, 13))
        assert cpu.m[0x0400 + 24] == 0x30 + error
    assert calls == [("name", b"GAME"), ("file", 1, 8, 1), ("load", 0)], calls
    if error is None:
        assert cpu.m[0x0810:0x0820] == game[0x11:0x21]


if __name__ == "__main__":
    for code in (None, 4, 5):
        check(sys.argv[1] if len(sys.argv) > 1 else "build/c64", code)
    print("PASS: intro loader success and error paths")
