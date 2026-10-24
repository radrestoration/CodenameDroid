"""Render the BBC game's whole screen buffer (all 32 cell rows) from a simulator's memory, with the
CRTC start address applied, and report which cell rows hold anything."""
import numpy as np
from PIL import Image
import bbcmem as bm


def ring_image(mem, S, scale=2):
    """S = ring cell index at the top left. Returns (PIL image 128x256 pixels x scale, set of non-blank rows)."""
    img = np.zeros((256, 128), dtype=np.uint8)
    nonblank = set()
    for r in range(32):
        for c in range(32):
            idx = (S + 32 * r + c) & 1023
            cell = mem[0x6000 + idx * 8:0x6000 + idx * 8 + 8]
            if any(cell):
                nonblank.add(r)
            for line in range(8):
                img[r * 8 + line, c * 4:c * 4 + 4] = bm.pixels(cell[line])
    rgb = np.array(bm.PALETTE, dtype=np.uint8)[img]
    return Image.fromarray(rgb).resize((128 * 2 * scale, 256 * scale), Image.NEAREST), nonblank
