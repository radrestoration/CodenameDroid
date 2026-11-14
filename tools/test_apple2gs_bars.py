#!/usr/bin/env python3
"""Run the IIgs boot block (build/apple2gs/bars.bin) in the 65816 interpreter and check the Super Hi-Res
screen it builds: 16 grey bars, palette 0, 320 mode, nothing written outside the pixel, SCB and palette areas.

Entry state assumed (UNVERIFIED on hardware, see APPLE-II-HANDOFF.md): block 0 at $0800, entered at $0801 in
emulation mode. Bank $E1 is pre-filled with junk so the code cannot rely on zeroed memory."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from sim65816 import Sim65816

boot = (ROOT / "build" / "apple2gs" / "bars.bin").read_bytes()
assert len(boot) == 512 and boot[0] == 0x01

s = Sim65816()
JUNK = 0xA5
s.mem[0xE10000:0xE20000] = bytes([JUNK]) * 0x10000
before = bytes(s.mem[0xE10000:0xE20000])
s.io[(0xE0, 0xC029)] = 0x01                # NEWVIDEO power-up: bit 0 (bank 1 latch) is set by the monitor
s.mem[0x0800:0x0A00] = boot
s.pc = 0x0801
halt = s.run(1_000_000)
assert halt == 0x0800 + boot.index(bytes([0x80, 0xFE])), hex(halt)    # stopped on its own BRA *
assert s.e == 0, "should be in native mode"

shr = bytes(s.mem[0xE10000:0xE20000])
# pixels: line y, byte x = bar (x // 10) * $11
for y in range(200):
    row = shr[0x2000 + 160 * y:0x2000 + 160 * (y + 1)]
    assert row == bytes((x // 10) * 0x11 for x in range(160)), f"line {y}"
# SCBs: palette 0, 320 mode, no fill, no interrupt, for all 200 lines
assert shr[0x9D00:0x9DC8] == bytes(200), "SCB"
# palette 0: entry n = grey n
for n in range(16):
    assert int.from_bytes(shr[0x9E00 + 2 * n:0x9E02 + 2 * n], "little") == n * 0x111, n
# nothing else in bank $E1 changed
for lo, hi in ((0, 0x2000), (0x9DC8, 0x9E00), (0x9E20, 0x10000)):
    assert shr[lo:hi] == before[lo:hi], f"unexpected write in ${lo:04X}-${hi - 1:04X}"
# bank 0 is untouched apart from the boot block itself
assert bytes(s.mem[0x0A00:0x10000]) == bytes(0x10000 - 0xA00)
# SHR on, linear, and the bank 1 latch bit preserved (read-modify-write)
assert s.io[(0xE0, 0xC029)] == 0xC1, hex(s.io[(0xE0, 0xC029)])
print(f"apple2gs boot block OK: {s.count} steps, 16 bars x 200 lines, SCB/palette set, $C029=$C1")
