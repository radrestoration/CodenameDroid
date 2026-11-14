#!/usr/bin/env python3
"""Run hal/apple/gs/draw.s (draw_view and the scroll routines) in the 65816 interpreter and compare the Super Hi-Res screen with a model
built straight from the BBC data (bbcmem), not from the converted tables, so the whole chain is checked:
BBC tiles -> converted cells/tiles/levels -> the 65816 routine -> pixels in bank $E1."""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import bbcmem
import make_apple2gs_tiles as conv
from asm65816 import cc65_bin
from sim65816 import Sim65816

B = ROOT / "build" / "apple2gs"
bin_ = cc65_bin()
B.mkdir(parents=True, exist_ok=True)
subprocess.run([str(bin_ / "ca65"), str(ROOT / "hal/apple/gs/draw.s"), "-l", str(B / "draw.lst"), "-o", str(B / "draw.o")],
               check=True)
subprocess.run([str(bin_ / "ld65"), "-C", str(ROOT / "hal/apple/gs/draw_test.cfg"), str(B / "draw.o"),
                "-o", str(B / "draw_test.bin"), "-Ln", str(B / "draw_test.lbl")], check=True)
subprocess.run([sys.executable, "-I", str(ROOT / "tools/make_apple2gs_tiles.py")], check=True, stdout=subprocess.DEVNULL)

sym = {}
for line in (B / "draw_test.lbl").read_text().splitlines():
    _, addr, name = line.split()
    sym[name.lstrip(".")] = int(addr, 16)
code = (B / "draw_test.bin").read_bytes()
cells, tiles, levels = (B / "cells.bin").read_bytes(), (B / "tiles.bin").read_bytes(), (B / "levels.bin").read_bytes()
assert len(tiles) < 0xA00 and len(levels) == 12 * 512

mem = bbcmem.load()
CODE = sym["draw_view"]
HALT = 0x0F00


def expected(level, cam_x, cam_y):
    grid = conv.level_tiles(level)               # [column][row]
    out = bytearray()
    for r in range(25):
        wy = cam_y + r
        lines = [bytearray() for _ in range(8)]
        for c in range(40):
            wx = cam_x + c
            tile = grid[wx // 4][wy // 4]
            cell = bbcmem.tile_cell_column(mem, tile, wx % 4)[wy % 4]
            for i, b in enumerate(cell):
                lines[i] += conv.shr_line(b)
        for ln in lines:
            out += ln
    return bytes(out)



class Session:
    """One simulated machine: call routines of the assembled draw.s one after another."""

    def __init__(self):
        s = self.s = Sim65816()
        s.mem[0xE10000:0xE20000] = bytes([0xA5]) * 0x10000
        s.mem[CODE:CODE + len(code)] = code
        s.mem[0x020000:0x020000 + len(cells)] = cells
        s.mem[0x030000:0x030000 + len(tiles)] = tiles
        s.mem[0x030A00:0x030A00 + len(levels)] = levels
        s.mem[HALT:HALT + 2] = bytes([0x80, 0xFE])
        s.e = 0
        s.p = 0x04                                      # native, 16-bit A and index
        s.sp = 0x01FF
        s.dbr = 0x77                                    # the routines must set and restore the data bank

    def call(self, name, a=0):
        s = self.s
        self.writes = {}                                # screen byte -> how many times this call wrote it
        orig_wr = s.wr

        def counting_wr(addr, v):
            addr &= 0xFFFFFF
            if 0xE12000 <= addr < 0xE12000 + 32000:
                self.writes[addr] = self.writes.get(addr, 0) + 1
            orig_wr(addr, v)
        s.wr = counting_wr
        try:
            return self._call(name, a)
        finally:
            s.wr = orig_wr

    def _call(self, name, a):
        s = self.s
        s.push16(HALT - 1)                              # RTS returns to the halt loop
        s.c = a
        s.pc = sym[name]
        before = (s.count, s.moved)
        s.run(5_000_000)
        assert s.dbr == 0x77 and s.sp == 0x01FF and s.e == 0, name
        return s.p & 1, s.count - before[0], s.moved - before[1]    # carry, instructions, bytes block-moved

    def screen(self):
        return bytes(self.s.mem[0xE12000:0xE12000 + 32000])

    def cam(self):
        return self.s.rd16(sym["cam_x"]), self.s.rd16(sym["cam_y"])


def check(sess, level, cam, what):
    assert sess.cam() == cam, (what, sess.cam(), cam)
    got, want = sess.screen(), expected(level, *cam)
    if got != want:
        first = next(i for i in range(32000) if got[i] != want[i])
        raise AssertionError(f"{what}: level {level} cam {cam}: first difference at byte {first} "
                             f"(line {first // 160}, byte {first % 160}): got {got[first]:02x} want {want[first]:02x}")
    mem = sess.s.mem
    outside = bytes(mem[0xE10000:0xE12000]) + bytes(mem[0xE19D00:0xE20000])
    assert outside == bytes([0xA5]) * len(outside), f"{what}: wrote outside the pixel area"


DELTA = {"scroll_right": (1, 0), "scroll_left": (-1, 0), "scroll_down": (0, 1), "scroll_up": (0, -1)}


def scenario(level, start, moves):
    sess = Session()
    sess.s.wr16(sym["cam_x"], start[0])
    sess.s.wr16(sym["cam_y"], start[1])
    carry, n, _ = sess.call("draw_view", level)
    check(sess, level, start, "draw_view")
    print(f"level {level:2d} draw_view at {start}: OK, {n} instructions")
    cam = start
    stats = {}
    for name in moves:
        dx, dy = DELTA[name]
        new = (cam[0] + dx, cam[1] + dy)
        legal = 0 <= new[0] <= 216 and 0 <= new[1] <= 7
        carry, n, moved = sess.call(name)
        if legal:
            assert carry == 0, (name, cam)
            cam = new
            stats[name] = (n, moved)
            # no transient state: every pixel byte is written exactly once, so the exposed edge never shows wrapped-around
            # or stale bytes between two writes
            w = sess.writes
            assert len(w) == 32000 and max(w.values()) == 1, \
                f"{name}: {len(w)} bytes written, most often {max(w.values())} times"
        else:
            assert carry == 1 and n < 20 and moved == 0, (name, cam, carry, n, moved)   # refused, nothing done
        check(sess, level, cam, f"{name} {'->' if legal else 'refused at'} {cam}")
    for name, (n, moved) in sorted(stats.items()):
        print(f"  {name:12s}: {n} instructions + block moves of {moved} bytes, every pixel byte written once")


scenario(3, (100, 3), ["scroll_right"] * 5 + ["scroll_left"] * 8 + ["scroll_down"] * 2 + ["scroll_up"] * 3
         + ["scroll_right", "scroll_down", "scroll_left", "scroll_up"])
scenario(0, (0, 0), ["scroll_left", "scroll_up", "scroll_right", "scroll_down", "scroll_left", "scroll_up"])
scenario(11, (210, 5), ["scroll_right"] * 8 + ["scroll_down"] * 4 + ["scroll_left"] * 3 + ["scroll_up"] * 9)
scenario(7, (1, 7), ["scroll_left"] * 3 + ["scroll_down"] + ["scroll_right"] * 2)
print("apple2gs draw_view and scrolling OK")
