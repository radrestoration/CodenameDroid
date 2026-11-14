#!/usr/bin/env python3
"""Boot the IIgs disk image (build/apple2gs/droid-gs.po) in the 65816 interpreter with a model of the slot-5 SmartPort.

The model is what the Apple IIgs Firmware Reference (ch. 7) and the working hfs-boot loader say the firmware does: block 0
at $0800, entry at $0801 in emulation mode with the slot in the high nibble of X; signature bytes in the slot ROM
($20, $00, $03, $00 at offsets 1, 3, 5, 7); the dispatch address is $Cs00 + [$CsFF] + 3; a standard ReadBlock
(JSR dispatch / DFB 1 / DW parameter list, list = {3, unit, buffer word, block 3 bytes}) must be made in emulation mode
with D = 0 and DBR = 0 and returns carry clear, A = 0, to JSR + 3 (the model asserts all of that).

Checks: every payload arrives where the load table says (memory elsewhere untouched), the demo draws the level exactly as
draw_view should, the keys scroll it, and read failures turn the border red and stop. Nothing here proves the real
firmware behaves like the model; the grey-bar run in GSplus did confirm the block-0 entry."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import bbcmem
import make_apple2gs_tiles as conv
from iigs_machine import Machine as _Machine, run_until, run_to_halt, labels, JUNK

B = ROOT / "build" / "apple2gs"
IMAGE = (B / "demo" / "demo.po").read_bytes()
assert len(IMAGE) == 800 * 1024


def Machine(**kwargs):
    return _Machine(IMAGE, **kwargs)


# ---- 1. the whole boot: loader, load table, demo, drawing, keys ----------------------------------------------
m = Machine()
dl = labels(B / "demo.lbl")
wait_key = dl["wait_key"]
run_until(m, wait_key)
expect_reads = list(range(1, 9)) + list(range(9, 69))
assert m.reads == expect_reads, f"blocks read: {m.reads[:12]}..."
files = {"demo.bin": (0x00, 0x2000), "palette.bin": (0x00, 0x1C00), "cells.bin": (0x02, 0x0000),
         "tiles.bin": (0x03, 0x0000), "levels.bin": (0x03, 0x0A00)}
for name, (bank, addr) in files.items():
    data = (B / name).read_bytes()
    got = bytes(m.mem[bank << 16 | addr:bank << 16 | addr + len(data)])
    assert got == data, f"{name} did not arrive intact at {bank:02X}:{addr:04X}"
print(f"loader: {len(m.reads)} blocks read in order; demo, palette, cells, tiles and levels are where the table says")

# memory the loader should not have touched: banks 2 - 4 outside the payloads (whole blocks), bank 0 above $4000
written = []
for name, (bank, addr) in files.items():
    blocks = -(-len((B / name).read_bytes()) // 512)
    written.append((bank, addr, addr + blocks * 512))
for bank in (0x02, 0x03, 0x04):
    spans = sorted((lo, hi) for b, lo, hi in written if b == bank)
    pos = 0
    for lo, hi in spans + [(0x10000, 0x10000)]:
        assert bytes(m.mem[(bank << 16) + pos:(bank << 16) + lo]) == bytes([JUNK]) * (lo - pos), f"bank {bank:02X} written outside the payloads"
        pos = hi
assert bytes(m.mem[0x4000:0xC000]) == bytes([JUNK]) * 0x8000, "bank 0 above $4000 was written"
assert (m.e, m.dbr) == (0, 0), "the demo should be waiting for keys in native mode, DBR 0"
assert m.io[(0xE0, 0xC029)] & 0xC0 == 0xC0 and m.io[(0xE0, 0xC034)] & 0x0F == 0, "Super Hi-Res on, black border"
assert bytes(m.mem[0xE19E00:0xE19E20]) == (B / "palette.bin").read_bytes(), "palette"
assert bytes(m.mem[0xE19D00:0xE19DC8]) == bytes(200), "scan-line control bytes"

mem = bbcmem.load()


def expected(level, cam_x, cam_y):
    grid = conv.level_tiles(level)
    out = bytearray()
    for r in range(25):
        lines = [bytearray() for _ in range(8)]
        for c in range(40):
            wx, wy = cam_x + c, cam_y + r
            cell = bbcmem.tile_cell_column(mem, grid[wx // 4][wy // 4], wx % 4)[wy % 4]
            for i, b in enumerate(cell):
                lines[i] += conv.shr_line(b)
        for ln in lines:
            out += ln
    return bytes(out)


def check(cam, what):
    got = bytes(m.mem[0xE12000:0xE12000 + 32000])
    want = expected(0, *cam)
    assert got == want, f"{what}: screen differs from the level at {cam}"


check((179, 0), "after boot")
print("demo: level 0 is drawn at the new-game camera (179,0), exactly as the tile model says")

# ---- the keys, through a model of GSplus's key queue. A tap scrolls once; a held key keeps scrolling with no repeat delay
# (the model says "a key is down" until `hold` scrolls have started); older queued events are skipped in favour of the newest, so
# a direction change takes effect at once even when stale auto-repeats of the old key are queued. Each case must settle at
# wait_key with the camera moved by the newest key and the screen equal to the level there.
m.scroll_pcs = {dl_scroll for dl_scroll in (labels(B / "demo.lbl")[n] for n in
                                           ("scroll_left", "scroll_right", "scroll_up", "scroll_down"))}
DIRS = {"X": (1, 0), "x": (1, 0), 0x15: (1, 0), "Z": (-1, 0), "z": (-1, 0), 0x08: (-1, 0), "M": (0, 1), 0x0A: (0, 1),
        "K": (0, -1), 0x0B: (0, -1), "Q": (0, 0)}
cam = [179, 0]
cases = [([k], 0) for k in DIRS]
cases += [(["X"], 1), (["X"], 6), (["Z"], 4), (["M"], 5), (["K"], 3), (["Q"], 4), (["X"], 50), (["M"], 12)]
cases += [(["Z"] * 7 + ["X"], 3), (["X"] * 7 + ["Z"], 2), (["M", "M", "M", "K"], 4), (["Z", "X", "Z", "X", "Z"], 0),
          (["X", "X"], 0), ([0x15] * 6 + ["Z"], 5)]
total = 0
for queue, hold in cases:
    dx, dy = DIRS[queue[-1]]
    m.kq = [k if isinstance(k, int) else ord(k) for k in queue]
    m.hold_total, m.scrolls_started = hold, 0
    before = m.key_reads
    for _ in range(6_000_000):
        m.step()
        if m.key_reads > before and not m.kq and (m.pbr << 16 | m.pc) == wait_key and m.scrolls_started >= (max(1, hold) if (dx, dy) != (0, 0) else 0):
            break
    else:
        raise AssertionError(f"keys {queue} held {hold}: did not settle at the key loop")
    times = max(1, hold) if (dx, dy) != (0, 0) else 0
    assert m.scrolls_started == times, f"keys {queue} held {hold}: {m.scrolls_started} scrolls, wanted {times}"
    for _ in range(times):
        cam = [min(max(cam[0] + dx, 0), 216), min(max(cam[1] + dy, 0), 7)]
    total += times
    assert m.mem[0x0000:0x0002] == bytes([cam[0], 0]) and m.mem[0x0002:0x0004] == bytes([cam[1], 0]), \
        f"keys {queue} held {hold}: camera {list(m.mem[0:4])}, wanted {cam}"
    check(tuple(cam), f"after keys {queue} held {hold}")
for _ in range(3000):                                    # idle: no key down, nothing queued: nothing moves
    m.step()
assert m.mem[0x0000:0x0002] == bytes([cam[0], 0]) and m.scrolls_started == times, "scrolled with no key down"
print(f"demo: {len(cases)} key cases (taps, lower case, arrows, an ignored key, holds of 1 - 50 scrolls into the right and bottom "
      f"limits, and queues of stale repeats followed by a new direction) gave {total} scrolls in the newest key's direction, "
      f"each ending with the screen equal to the level at the camera")

# ---- 2. failures: the border goes red and nothing more is loaded
for what, kwargs, nblocks in (("a stage 1 block fails", dict(fail_block=3), 3), ("a payload block fails", dict(fail_block=20), 20),
                              ("the slot has no SmartPort signature", dict(bad_signature=True), 0)):
    f = Machine(**kwargs)
    halt = run_to_halt(f)
    border = f.io.get((0, 0xC034), 0) & 0x0F
    assert border == 1, f"{what}: border {border}, wanted red (1)"
    assert f.reads == list(range(1, nblocks + 1)), f"{what}: reads {f.reads}"
    assert f.io.get((0, 0xC029), 0) == 0, f"{what}: Super Hi-Res must not be on"
    print(f"failure: {what}: border red, halted at ${halt:04X} after {len(f.reads)} reads")
print("apple2gs loader OK")
