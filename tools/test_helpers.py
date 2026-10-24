#!/usr/bin/env python3
"""The geometry helpers (ring_ops.s) against a model of the ring's arithmetic, for the build in C64_BUILD (32 or 40 columns):
random inputs, the routine called as a subroutine in the simulator.   test_helpers.py"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64sim import C64, RING_W, RING, RING_CELLS  # noqa: E402
import wide_patches  # noqa: E402

S = RING_W * 8
SIZE = RING_CELLS * 8
SYM = wide_patches.SYMS


def zp(name):
    return SYM[name]


def put16(m, lo_name, v):
    m[zp(lo_name)] = v & 255
    m[zp(lo_name) + 1] = v >> 8


def get16(m, lo_name):
    return m[zp(lo_name)] | m[zp(lo_name) + 1] << 8


def wrap(v):
    return RING + (v - RING) % SIZE


def rnd_addr(r, aligned=False):
    a = RING + r.randrange(SIZE)
    return a & ~7 if aligned else a


def main():
    r = random.Random(1)
    c = C64()
    m = c.m
    c.call("cells_init", max_steps=2_000_000)        # (makes the row and column tables of the wide ring)
    bad = 0

    def check(what, got, want):
        nonlocal bad
        if got != want:
            bad += 1
            if bad < 20:
                print("FAIL %s: got %s, want %s" % (what, got, want))

    labels = c.syms
    # ring_add helpers: (name, source, destination, offset)
    ring_adds = [("psa_down", "player_screen_address_low", "player_screen_address_low", S),
                 ("sa_down2", "screen_address_low", "screen_address_low", 2 * S),
                 ("ground_below", "screen_address_low", "ground_screen_address_low", S),
                 ("start_plus_31_rows", "screen_start_address_low", "screen_address_low", 31 * S),
                 ("psa_up4", "player_screen_address_low", "screen_address_low", -4 * S),
                 ("map_start", "screen_start_address_low", "map_screen_address_low", 10 * S),
                 ("map_down", "map_screen_address_low", "map_screen_address_low", S),
                 ("sa_next_group7", "screen_address_low", "screen_address_low", S - 7),
                 ("sa_next_group8", "screen_address_low", "screen_address_low", S - 8),
                 ("start_up", "screen_start_address_low", "screen_start_address_low", -S),
                 ("psa_up4lines", "player_screen_address_low", "player_screen_address_low", -(S - 4)),
                 ("psa_up4lines_sa", "player_screen_address_low", "screen_address_low", -(S - 4))]
    for name, src, dst, k in ring_adds:
        if "wide_" + name not in labels:
            continue
        for _ in range(300):
            a = rnd_addr(r)
            put16(m, src, a)
            c.call("wide_" + name)
            check(name, get16(m, dst), wrap(a + k))
    # the player's plots' next group: column_screen_address
    for _ in range(300):
        a = rnd_addr(r)
        put16(m, "column_screen_address_low", a)
        c.call("wide_col_next_group7")
        want = wrap(a + S - 7)
        check("col_next_group7", get16(m, "column_screen_address_low"), want)
        check("col_next_group7 sa", get16(m, "screen_address_low"), want)
    # scroll rows
    for _ in range(300):
        a, b = rnd_addr(r), rnd_addr(r)
        put16(m, "screen_start_address_low", a)
        put16(m, "player_screen_address_low", b)
        c.call("wide_scroll_up_rows")
        check("scroll_up start", get16(m, "screen_start_address_low"), wrap(a - S))
        check("scroll_up psa", get16(m, "player_screen_address_low"), wrap(b - S))
        c.call("wide_scroll_down_rows")
        check("scroll_down start", get16(m, "screen_start_address_low"), a)
        check("scroll_down psa", get16(m, "player_screen_address_low"), b)
    # rows -> offset
    for rows in range(32):
        m[0xe0] = 0
        c.cpu.a = rows
        c.call("wide_rows")
        check("rows %d" % rows, (m[0x219] << 8) | m[0x218], rows * S)
    # calculate_screen_address
    for _ in range(500):
        start = rnd_addr(r, True)
        put16(m, "screen_start_address_low", start)
        x, y = r.randrange(32), r.randrange(256)
        c.cpu.x, c.cpu.y = x, y
        c.call("wide_calc_screen_address")
        check("calc_screen_address(%d,%d)" % (x, y), get16(m, "screen_address_low"), wrap(start + (y >> 3) * S + x * 8 + (y & 7)))
    # the player's row in the window
    for _ in range(500):
        srow = r.randrange(8)          # (the game keeps the window's top within the first 8 rows, and the player below it
        start = RING + srow * S + r.randrange(RING_W) * 8        # without wrapping)
        row = r.randrange(24)
        col = r.randrange(RING_W)
        line = r.randrange(8)
        psa = start + row * S + col * 8 + line
        if psa == start:
            continue
        put16(m, "screen_start_address_low", start)
        put16(m, "player_screen_address_low", psa)
        c.cpu.x = 0
        c.call("wide_player_offset")
        want = ((psa - start - 1) % SIZE) // S
        check("player_offset row %d col %d" % (row, col), c.cpu.x, want)
    # replot_tile's address: Y = relative tile x, $78 = fraction, $7b = tile y
    for _ in range(500):
        start = RING + r.randrange(8) * S + r.randrange(RING_W) * 8
        put16(m, "screen_start_address_low", start)
        ty = r.randrange(8)
        frac = r.randrange(4)
        rel = r.randrange(RING_W // 4 + 1)
        cells = rel * 4 - frac
        if cells < 0:
            continue
        m[0x78] = frac
        m[0x7b] = ty
        c.cpu.y = rel
        c.call("wide_replot_address")
        check("replot_address", get16(m, "screen_address_low"), wrap(start + cells * 8 + ty * 4 * S))
    # a mine at the edge
    for _ in range(300):
        edge = rnd_addr(r, True)
        m[zp("edge_screen_address_low")] = edge & 255          # (not adjacent to its high byte)
        m[zp("edge_screen_address_high")] = edge >> 8
        grp, rig = r.randrange(32), r.randrange(8)
        m[zp("group")] = grp
        m[zp("row_in_group")] = rig
        c.call("wide_mine_address")
        check("mine_address", get16(m, "screen_address_low"), wrap(edge + grp * S + rig))
    # the blaster at the window's edge
    for _ in range(500):
        start = RING + r.randrange(8) * S + r.randrange(RING_W) * 8
        put16(m, "screen_start_address_low", start)
        col = r.randrange(RING_W)
        row = r.randrange(32)
        b = wrap(start + row * S + col * 8 + r.randrange(8))
        slot = r.randrange(6) * 4
        m[zp("blasters_screen_address_low") + slot] = b & 255
        m[zp("blasters_screen_address_high") + slot] = b >> 8
        c.cpu.x = slot
        c.call("wide_blaster_at_edge")
        if RING_W == 32:
            want = ((b & 0xf8) == (start & 0xff))
        else:
            want = col == 0
        check("blaster_at_edge col %d" % col, bool(c.cpu.z), want)
    print("PASS" if bad == 0 else "FAIL (%d)" % bad)
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
