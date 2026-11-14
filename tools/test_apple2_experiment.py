#!/usr/bin/env python3
"""Verify the assembled HGR redraw against the generated world and glyphs."""
import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sim6502 import CPU
from sim_check import labels

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build" / "apple2"


def main():
    binary = (BUILD / "scroll.bin").read_bytes()
    world = (BUILD / "world.bin").read_bytes()
    glyphs = (BUILD / "glyphs.bin").read_bytes()
    sym = labels(str(BUILD / "scroll.lbl"))
    assert len(world) == 24 * 256 and len(glyphs) == 8 * 256
    cpu = CPU()
    cpu.m[0x4000:0x4000 + len(binary)] = binary

    def call(name):
        start = cpu.cycles
        cpu.push(0x07)
        cpu.push(0xFF)
        cpu.pc = sym[name]
        while cpu.pc != 0x0800:
            if cpu.cycles - start > 1_000_000:
                raise AssertionError(f"{name} did not finish")
            cpu.step()
        return cpu.cycles - start

    def check(window):
        if cpu.m[sym["world_x"]] != window:
            raise AssertionError(f"wrong viewport after scrolling to {window}")
        for y in range(192):
            address = 0x2000 + (y % 8) * 0x400 + ((y // 8) % 8) * 0x80 + (y // 64) * 40
            expected = bytes(glyphs[(y % 8) * 256 + world[(y // 8) * 256 + window + x]]
                             for x in range(40))
            actual = bytes(cpu.m[address:address + 40])
            if actual != expected:
                raise AssertionError(f"window {window}, scanline {y} differs")

    for window in (0, 1, 39, 40, 127, 128, 175, 176, 215, 216):
        cpu.m[sym["world_x"]] = window
        cycles = call("draw")
        check(window)
        print(f"full redraw at {window}: {cycles} simulated cycles")
        moves = [("scroll_left", max(0, window - 1))]
        if window > 0:
            moves.append(("scroll_right", window))
        moves.append(("scroll_right", min(216, window + 1)))
        if window < 216:
            moves.append(("scroll_left", window))
        for name, target in moves:
            cycles = call(name)
            check(target)
            print(f"{name} to {target}: {cycles} simulated cycles")


if __name__ == "__main__":
    main()
