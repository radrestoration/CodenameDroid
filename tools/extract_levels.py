#!/usr/bin/env python3
"""Decode the 12 level maps from build/CDroid4 and render them as PNGs
(BBC colours, pixels doubled horizontally to give MODE 5's 2:1 shape), so the
decoding can be checked by eye without running anything.

    extract_levels.py OUTDIR
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bbcmem as bm  # noqa: E402

NAMES = ["surface1", "surface2", "surface3", "shrine1", "shrine2", "shrine3",
         "crew1", "crew2", "crew3", "factory1", "factory2", "factory3"]


def render(mem, level):
    first, end = bm.LEVEL_COLUMNS[level]
    cols = bm.level_tiles(mem, level)[first:end]
    img = np.zeros((256, len(cols) * 16), dtype=np.uint8)
    chars = set()
    for c, col in enumerate(cols):
        for ty, tile in enumerate(col):
            for xf in range(4):
                for k, cell in enumerate(bm.tile_cell_column(mem, tile, xf)):
                    chars.add(cell)
                    for line, b in enumerate(cell):
                        img[ty * 32 + k * 8 + line, (c * 4 + xf) * 4:(c * 4 + xf) * 4 + 4] = bm.pixels(b)
    return img, len(chars - {bytes(8)})


def save(img, path):
    rgb = np.array(bm.PALETTE, dtype=np.uint8)[img]
    rgb = np.repeat(rgb, 2, axis=1)                       # 2:1 pixels
    Image.fromarray(rgb).save(path)


def main(outdir):
    os.makedirs(outdir, exist_ok=True)
    mem = bm.load()
    for lv in range(bm.NUM_LEVELS):
        img, n = render(mem, lv)
        save(img, os.path.join(outdir, "level_%02d_%s.png" % (lv, NAMES[lv])))
        print("level %2d %-9s %2d columns  %3d distinct characters" % (lv, NAMES[lv], img.shape[1] // 16, n))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
