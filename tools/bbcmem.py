"""The BBC game's run-time memory, read from the rebuilt CDroid4 (../build/CDroid4),
and decoders for its level maps and tile graphics.

CDroid4 layout (see ../../disc.cfg): the game &1100-&57ff, the tile block &5800-&5fff
in place, then the blocks the startup code moves: &0400-&10ff, &03a0, &0180, &0380, &0300.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
CDROID4 = os.path.join(HERE, "..", "build", "bbc", "CDroid4")

# BBC MODE 5 logical colours in this game: black, red, cyan (VDU 19,2,6 in the
# startup code), white
PALETTE = [(0, 0, 0), (255, 0, 0), (0, 255, 255), (255, 255, 255)]

# tiles whose right half (x fraction 2 and 3) is the mirror of the left half
# (plot_column_of_tiles, &190d-&192b)
MIRRORED_TILES = {0x0e, 0x32, 0x11, 0x12, 0x13, 0x23, 0x14, 0x08}

NUM_LEVELS = 12
LEVEL0_DATA = 0x5700            # level n is at LEVEL0_DATA - &100 * n; 64 columns of 4 bytes


def load(path=CDROID4):
    f = open(path, "rb").read()
    assert len(f) == 0x5e00
    mem = bytearray(0x10000)
    for dest, src, n in ((0x1100, 0x0000, 0x4700), (0x5800, 0x4700, 0x800),
                         (0x0400, 0x4f00, 0xd00), (0x03a0, 0x5c00, 0x40),
                         (0x0180, 0x5c40, 0x40), (0x0380, 0x5c80, 0x20),
                         (0x0300, 0x5ca0, 0x60)):
        mem[dest:dest + n] = f[src:src + n]
    return mem


# Columns of a level's 64-column page that are the level. Level 7 is the second half
# of its page (the listing's "level_7_data + &80"; the first half is level_names,
# object_sprite_disk and the completion screen's map); level 11 is the first half
# (followed by object sprites). Both end in wall columns at the boundary.
LEVEL_COLUMNS = {lv: (0, 64) for lv in range(NUM_LEVELS)}
LEVEL_COLUMNS[7] = (32, 64)
LEVEL_COLUMNS[11] = (0, 32)


def mirror_byte(b):
    """Mirror the four 2-bit pixels of a MODE 5 byte (pixel n is bit 7-n, bit 3-n)."""
    px = [((b >> (7 - n)) & 1) << 1 | ((b >> (3 - n)) & 1) for n in range(4)][::-1]
    return sum(((p >> 1) & 1) << (7 - n) | (p & 1) << (3 - n) for n, p in enumerate(px))


def pixels(b):
    """The four pixel values (0-3), left to right, of a MODE 5 byte."""
    return [((b >> (7 - n)) & 1) << 1 | ((b >> (3 - n)) & 1) for n in range(4)]


def translation(mem, level):
    """level_tiles_translation_table as it stands in `level`: the stored table plus
    the patches the game makes (set_level_specific_tiles &1274; the surface defence
    patch at &16cd on first using a lift; the spaceship at &1744 for level 11)."""
    t = bytearray(mem[0x520:0x570])
    if level >= 1:                                        # &16cd-&16d8
        t[0x09], t[0x0a], t[0x0c], t[0x0d] = 0x10, 0x0f, 0x16, 0x14
    if level < 8:                                         # tables for Crew's Quarters 1, 2
        t[0x26], t[0x27] = 0x1d, 0x1c
    else:                                                 # pipes
        t[0x26], t[0x27] = 0x06, 0x04
        if level < 10:
            t[0x35], t[0x37] = 0x30, 0x2e                 # missile
        else:
            t[0x35], t[0x37] = 0x36, 0x34                 # spaceship
    if level == 11:
        t[0x35], t[0x37] = 0x36, 0x37
    return t


def level_tile_set(mem, level):
    return mem[0x4bc0 + level]                            # level_offsets_table


def level_tiles(mem, level):
    """[column][row] of tile numbers (0-0x4b) for a level: 64 columns x 8 rows."""
    base = LEVEL0_DATA - 0x100 * level
    tr, off = translation(mem, level), level_tile_set(mem, level)
    cols = []
    for c in range(64):
        col = []
        for y in range(8):
            b = mem[base + c * 4 + (y >> 1)]
            nib = (b >> 4) if y & 1 else b & 15
            col.append(tr[off + nib])
        cols.append(col)
    return cols


def tile_cell_column(mem, tile, xf):
    """The 4 cells (8 bytes each, top to bottom) of one character column (x fraction
    0-3) of a tile, as plot_column_of_tiles draws them."""
    lo, hi = mem[0x0f80 + 2 * tile], mem[0x0f81 + 2 * tile]
    base, flip = (hi << 8) | (lo & 0xf8), lo & 3
    if xf >= 2 and tile in MIRRORED_TILES:
        flip |= 2
    src = base + ((3 - xf) if flip >= 2 else xf) * 32
    data = list(mem[src:src + 32])
    if flip & 2:
        data = [mirror_byte(b) for b in data]
    if flip & 1:
        data = data[::-1]
    return [bytes(data[r * 8:r * 8 + 8]) for r in range(4)]
