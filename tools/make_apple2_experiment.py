#!/usr/bin/env python3
"""Build monochrome HGR cells for the Apple II scrolling experiment."""
import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bbcmem
from sim_check import labels

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "apple2"


def main():
    bbc = bbcmem.load()
    game_dir = Path(sys.argv[1])
    program = (game_dir / "game.prg").read_bytes()
    origin = int.from_bytes(program[:2], "little")
    sym = labels(str(game_dir / "game.lbl"))

    def data(name, size):
        offset = 2 + sym[name] - origin
        if offset < 2 or offset + size > len(program):
            raise ValueError(f"{name} outside C64 game image")
        return program[offset:offset + size]

    tiles = data("level_tiles0", 256)
    xlat = data("level_xlat", 16)
    glyph_ids = {}
    glyphs = []
    world = bytearray()
    for row in range(24):
        tile_y, cell_y = divmod(row, 4)
        for col in range(256):
            tile_x, cell_x = divmod(col, 4)
            packed = tiles[tile_x * 4 + tile_y // 2]
            nibble = (packed >> (4 * (tile_y & 1))) & 15
            lines = bbcmem.tile_cell_column(bbc, xlat[nibble], cell_x)[cell_y]
            glyph = bytes(
                sum((1 << x) for x, pixel in enumerate((0, 0, 1, 1, 2, 2, 3))
                    if bbcmem.pixels(line)[pixel])
                for line in lines
            )
            if glyph not in glyph_ids:
                if len(glyphs) == 256:
                    raise ValueError("surface needs more than 256 HGR glyphs")
                glyph_ids[glyph] = len(glyphs)
                glyphs.append(glyph)
            world.append(glyph_ids[glyph])
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "world.bin").write_bytes(world)
    (OUT / "glyphs.bin").write_bytes(bytes(
        glyphs[index][line] if index < len(glyphs) else 0
        for line in range(8) for index in range(256)
    ))
    print(f"Apple II experiment: {len(glyphs)} glyphs, {len(world)} world cells")


if __name__ == "__main__":
    main()
