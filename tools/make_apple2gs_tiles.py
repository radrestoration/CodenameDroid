#!/usr/bin/env python3
"""Convert the BBC game's tile graphics and level maps to Apple IIgs Super Hi-Res (320 mode) data.

Geometry: a BBC MODE 5 cell is 4 pixels x 8 lines (2 bits per pixel, 8 bytes). Each BBC pixel becomes two
SHR 320-mode pixels, so a cell is 8 pixels (4 bytes) x 8 lines = 32 bytes; 40 cells x 25 rows fill 320x200,
the same play area as the C64 port. SHR 320 mode packs two 4-bit palette indices per byte (left pixel in the
high nibble); we use indices 0-3 for the BBC's four logical colours.

Outputs (build/apple2gs/):
  cells.bin    N unique cells x 32 bytes (8 lines x 4 bytes)
  tiles.bin    tile number (0-0x4b) x 16 little-endian cell indices, row-major (4 rows x 4 columns)
  levels.bin   12 levels x 64 columns x 8 rows of tile numbers, column-major, from the C64 build's level data (needs
               build/c64/game.prg): the game's maps, not the raw disc data
  bbc2shr.bin  256 x 4 bytes: a BBC MODE 5 byte as four SHR bytes (the hardware layer's character converter)
  palette.bin  16 SHR palette entries (little-endian xRGB words); entries 0-3 are the BBC colours
"""
import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bbcmem

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "apple2gs"
NUM_TILES = 0x4c


def level_tiles(level):
    """[column][row] of tile numbers for a level as the game has it at the start: the C64 build's level map
    (`level_tiles0`, a page a level, 64 columns of 4 bytes holding two nibbles each) through its translation table
    (`level_xlat`, 16 bytes a level; level 0's has the spaceship's tiles). make_data.py made them from the BBC's data
    and applied the BBC's startup edits (lift removal, `initialise_levels`' initial tiles), which the raw disc data
    (bbcmem.level_tiles) does not have: drawn from the raw data the surface's rock and ship tiles are mixed up."""
    prg = (ROOT / "build/c64/game.prg").read_bytes()
    origin = int.from_bytes(prg[:2], "little")
    labels = {}
    for line in (ROOT / "build/c64/game.lbl").read_text().splitlines():
        p = line.split()
        if len(p) == 3 and p[0] == "al":
            labels[p[2].lstrip(".")] = int(p[1], 16)

    def data(name, offset, size):
        start = 2 + labels[name] - origin + offset
        return prg[start:start + size]

    page, xlat = data("level_tiles0", level * 256, 256), data("level_xlat", level * 16, 16)
    return [[xlat[(page[c * 4 + (y >> 1)] >> (4 if y & 1 else 0)) & 15] for y in range(8)] for c in range(64)]


def shr_line(bbc_byte):
    """One BBC byte (4 pixels) as 4 SHR bytes (two nibbles per byte, each pixel doubled)."""
    return bytes(p * 0x11 for p in bbcmem.pixels(bbc_byte))


def shr_cell(cell):
    return b"".join(shr_line(b) for b in cell)


def palette():
    words = [((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4) for r, g, b in bbcmem.PALETTE]
    return b"".join(w.to_bytes(2, "little") for w in words + [0] * (16 - len(words)))


def build(mem):
    cells, index = [], {}
    tiles = bytearray()
    for tile in range(NUM_TILES):
        columns = [bbcmem.tile_cell_column(mem, tile, xf) for xf in range(4)]
        for row in range(4):
            for xf in range(4):
                data = shr_cell(columns[xf][row])
                if data not in index:
                    index[data] = len(cells)
                    cells.append(data)
                tiles += index[data].to_bytes(2, "little")
    levels = bytearray()
    for level in range(bbcmem.NUM_LEVELS):
        for col in level_tiles(level):
            levels += bytes(col)
    return b"".join(cells), bytes(tiles), bytes(levels), palette()


def main():
    cells, tiles, levels, pal = build(bbcmem.load())
    OUT.mkdir(parents=True, exist_ok=True)
    bbc2shr = b"".join(shr_line(b) for b in range(256))
    for name, data in (("cells", cells), ("tiles", tiles), ("levels", levels), ("palette", pal), ("bbc2shr", bbc2shr)):
        (OUT / f"{name}.bin").write_bytes(data)
    print(f"Apple IIgs tiles: {len(cells) // 32} cells ({len(cells)} bytes), {NUM_TILES} tiles, "
          f"{bbcmem.NUM_LEVELS} levels")


if __name__ == "__main__":
    main()
