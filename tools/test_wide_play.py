#!/usr/bin/env python3
"""The 40-column build in play: the window's picture against the level's data. Each cell of the ring's window should be the
cell the level's tiles give at that place (level column left_edge + c, row r), except where something is drawn over the
background (the player, stars, objects, mines, blasters, enemies). Walks right and left through the first levels.
   test_wide_play.py [frames] [script]"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from bbcsim import KEYS  # noqa: E402
from c64sim import C64, RING, RING_W, RING_CELLS, CRTC_BASE  # noqa: E402
import bbcmem as bm  # noqa: E402
import test_diff  # noqa: E402
import wide_patches  # noqa: E402

SYM = wide_patches.SYMS
MEM = bm.load()
TILES = {}


def level_tiles(level):
    if level not in TILES:
        TILES[level] = bm.level_tiles(MEM, level)
    return TILES[level]


def expected(level, x, r):
    if not 0 <= x < 256:
        return None
    tile = level_tiles(level)[x // 4][r // 4]
    return bm.tile_cell_column(MEM, tile, x % 4)[r % 4]


def check(c, who=""):
    m = c.m
    level = m[SYM["level"]]
    if level >= bm.NUM_LEVELS:
        return None
    left = m[SYM["left_edge_tile_address_low"]] + m[SYM["left_edge_x_fraction"]]
    S = ((m[0x200] - CRTC_BASE) << 8) | m[0x201]
    psa = m[SYM["player_screen_address_low"]] | m[SYM["player_screen_address_high"]] << 8
    pcell = ((psa - RING) >> 3) % RING_CELLS
    prow, pcol = ((pcell - S) % RING_CELLS) // RING_W, ((pcell - S) % RING_CELLS) % RING_W
    bad = []
    for r in range(32):
        for cc in range(RING_W):
            idx = (S + RING_W * r + cc) % RING_CELLS
            got = bytes(m[RING + idx * 8:RING + idx * 8 + 8])
            want = expected(level, left + cc, r)
            if want is None or got == want:
                continue
            if prow - 1 <= r <= prow + 4 and pcol - 2 <= cc <= pcol + 4:       # the player and his blaster
                continue
            if sum(1 for b in got if b) <= 1:                                   # a star
                continue
            bad.append((r, cc, left + cc))
    return left, bad


def main(frames, script_text):
    script = test_diff.parse_script(script_text)
    c = C64()
    worst = 0
    for f in range(frames):
        held = test_diff.keys_at(script, f)
        c.held = [KEYS[k] for k in held]
        c.apply_keys()
        c.run_frames(1)
        if c.m[0x207] == 1 and f % 3 == 0:
            res = check(c)
            if res and res[1]:
                left, bad = res
                worst = max(worst, len(bad))
                if len(bad) > 0:
                    print("frame %d: level %d left edge %d: %d cells differ from the level, e.g. %s"
                          % (f, c.m[SYM["level"]], left, len(bad), bad[:6]))
                    return 1
    m = c.m
    print("%d frames (player x %d, level %d, window left edge %d): the window matched the level's tiles throughout"
          % (frames, m[SYM["player_x"]], m[SYM["level"]], m[SYM["left_edge_tile_address_low"]]))
    return 0


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 1500
    script = sys.argv[2] if len(sys.argv) > 2 else "SPACE@140-200,X@260-700,Z@800-1300,X@1350-1500"
    sys.exit(main(n, script))
