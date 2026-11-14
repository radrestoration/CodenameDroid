#!/usr/bin/env python3
"""Check the Super Hi-Res tile data against the BBC source: every cell of every tile decodes back to the
original MODE 5 bytes, the level maps match, and the palette is the BBC's."""
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import bbcmem
import make_apple2gs_tiles as m

subprocess.run([sys.executable, "-I", str(HERE / "make_apple2gs_tiles.py")], check=True)
cells = (m.OUT / "cells.bin").read_bytes()
tiles = (m.OUT / "tiles.bin").read_bytes()
levels = (m.OUT / "levels.bin").read_bytes()
pal = (m.OUT / "palette.bin").read_bytes()
mem = bbcmem.load()

assert len(cells) % 32 == 0 and len(tiles) == m.NUM_TILES * 32 and len(pal) == 32
count = len(cells) // 32


def bbc_byte(four_bytes):
    """Re-pack 4 SHR bytes (doubled pixels) into the BBC MODE 5 byte."""
    px = []
    for b in four_bytes:
        assert b >> 4 == b & 15 and b & 15 < 4, f"not a doubled 2-bit pixel: {b:02x}"
        px.append(b & 15)
    return sum(((p >> 1) & 1) << (7 - n) | (p & 1) << (3 - n) for n, p in enumerate(px))


for tile in range(m.NUM_TILES):
    columns = [bbcmem.tile_cell_column(mem, tile, xf) for xf in range(4)]
    for row in range(4):
        for xf in range(4):
            idx = int.from_bytes(tiles[tile * 32 + (row * 4 + xf) * 2:][:2], "little")
            assert idx < count, (tile, row, xf, idx)
            cell = cells[idx * 32:idx * 32 + 32]
            got = bytes(bbc_byte(cell[line * 4:line * 4 + 4]) for line in range(8))
            assert got == columns[xf][row], (tile, row, xf)

expected = b"".join(bytes(col) for lv in range(bbcmem.NUM_LEVELS) for col in m.level_tiles(lv))
assert levels == expected and len(levels) == bbcmem.NUM_LEVELS * 64 * 8
assert all(t < m.NUM_TILES for t in levels)
assert pal[:8] == bytes([0x00, 0x00, 0x00, 0x0f, 0xff, 0x00, 0xff, 0x0f]), pal[:8].hex()
print(f"apple2gs tiles OK: {count} cells, {m.NUM_TILES} tiles round-trip to the BBC bytes, levels and palette match")
