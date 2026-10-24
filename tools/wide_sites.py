"""The sites of wide_patches.py (see there). Line numbers are those of the pristine src/droid.s.

Groups:
  constants   the ring's start, its size, the CRTC base, the window width where it is a plain immediate
  offsets     16-bit address offsets built of two immediates (rows * 256 + cells * 8 + lines in the BBC's ring)
  blocks      row steps and the like: calls of the helpers in ring_ops.s
  whole       routines and sequences replaced by a helper
  tables      the offset tables (duplicated for the wide ring, the originals untouched)
"""
import re

from wide_patches import Edit, decompose, size_of_lines, strip_comment

# lda/cmp #$60: the start of the ring (a wrap; or the ring's first page as an initial value)
RING_START = [295, 338, 392, 417, 560, 661, 668, 746, 751, 819, 840, 1294, 1328, 1354, 1385, 1470, 1523, 1556, 1601,
              1696, 1713, 1753, 1809, 1824, 1912, 1936, 2265, 2279, 2435, 2473, 2506, 2615, 2650, 2665, 2739, 3714,
              3742, 3778, 3794, 3940, 4054, 4105, 4785, 5442, 6130, 6158, 6202, 6229, 6309, 6325, 6344, 6425, 6680,
              6691, 6960]
# sbc #$20 after a sign test: subtract the size of the ring from the high byte
RING_SIZE_SUB = [287, 781, 2023, 2322, 2333, 2348, 2359, 2389, 2410, 2554, 2766, 2781, 3016, 3159, 3845, 4062, 4082,
                 4278, 4408, 4444, 4510, 4813, 5086, 5364, 5467, 5718, 5855, 6838]
# adc #$20 after a bounds test: add it
RING_SIZE_ADD = [822, 2268, 2282, 2742]

# (low line, high line, op): an offset from the player's or the window's address: rows * 256 + cells * 8 + lines
PAIRS = [(2261, 2264, "sbc"), (2275, 2278, "sbc"), (2316, 2319, "adc"), (2327, 2330, "adc"), (2342, 2345, "adc"),
         (2353, 2356, "adc"), (2382, 2386, "adc"), (2403, 2407, "adc"), (2760, 2763, "adc"), (3010, 3013, "adc"),
         (3153, 3156, "adc"), (4426, 4429, "adc"), (4437, 4440, "adc"), (5080, 5083, "adc"), (5461, 5464, "adc")]
# the player's blaster: the offset from the player's address where it starts (lda pairs)
BLASTER_LDA = [(6780, 6782), (6787, 6789), (6845, 6847), (6852, 6854)]

PSA = ("player_screen_address_low", "player_screen_address_high")
SA = ("screen_address_low", "screen_address_high")
START = ("screen_start_address_low", "screen_start_address_high")
MAP = ("map_screen_address_low", "map_screen_address_high")
COL = ("column_screen_address_low", "column_screen_address_high")
GROUND = ("ground_screen_address_low", "ground_screen_address_high")


def ring_add(src, dst, k, rts=True):
    """Helper text: dst := src + k (k a ca65 expression), wrapped into the ring."""
    return "    RING_ADD %s, %s, %s, %s, %s%s" % (src[0], src[1], dst[0], dst[1], k, "\n    rts" if rts else "")


def sites(p):
    blocks(p)
    whole(p)
    tables(p)
    semantic(p)
    constants(p)
    offsets(p)


# ------------------------------------------------------------------------------------------------------------------
def constants(p):
    for n in RING_START:
        p.imm(n, 0x60, "RING_HI", ops=("lda", "cmp"))
    for n in RING_SIZE_SUB:
        p.imm(n, 0x20, "RING_SZ_HI", ops=("sbc",))
    for n in RING_SIZE_ADD:
        p.imm(n, 0x20, "RING_SZ_HI", ops=("adc",))
    # the CRTC start address (in cells): its base, and a row is RING_W cells
    # the lift's graphics are in the tile block ($5e00 = TILES + $600)
    for n in (827, 854):
        p.imm(n, 0x5e, "(>TILES) + 6", ops=("lda",))
    p.imm(5823, 0x5b, "(>TILES) + 3", ops=("lda",))      # the font ($5b00)
    # the skeleton sprites are in the tile block too ($5da0, $5de8: the table of their addresses)
    p.byte_hi(7693, 0x5d, ">TILES + $05")
    p.byte_hi(7695, 0x5d, ">TILES + $05")
    for n in (464, 740, 3904, 6423):
        p.imm(n, 0x0c, "CRTC_HI", ops=("lda",))
    for n in (623, 652, 6981):
        p.imm(n, 0x0c, "CRTC_HI", ops=("cmp",))
    for n in (647, 6977, 6970, 6988):
        p.imm(n, 0x20, "RING_W", ops=("sbc",))
    p.imm(732, 0x20, "RING_W", ops=("adc",))
    p.imm(6993, 0x20, "RING_W", ops=("lda",))     # display_level draws a window's worth of columns


def offsets(p):
    for lo, hi, op in PAIRS:
        p.pair(lo, hi, op)
    for lo, hi in BLASTER_LDA:
        p.lda_pair(lo, hi)
    # the blaster fired from a kneeling or aligned player: a hi byte of 2 from the line before, a new low byte
    p.pair_lo_only(6794, 0x021a, hi_line=6789)
    # kneeling and aligned: + 5 bytes, then + $f8 (a cell row less a cell)
    lo, hi = p.off16(1, -1, 0)
    p.explicit_pair(6812, 6815, lo, hi, 0x00f8)


# ------------------------------------------------------------------------------------------------------------------
def rows_helper(p):
    """wide_rows: A = a number of cell rows (0-31) -> c64_t1:c64_t0 = that many strides."""
    return p.helper("rows", """    sta c64_t1
.if RING_W = 32
    lda #0
    sta c64_t0
.else
    ; rows * 320 = rows * 256 + rows * 64
    and #3
    lsr
    ror
    ror                         ; (rows and 3) * 64
    sta c64_t0
    lda c64_t1
    lsr
    lsr
    clc
    adc c64_t1                  ; rows + rows / 4
    sta c64_t1
.endif
    rts""")


def blocks(p):
    S = "STRIDE"
    rows = rows_helper(p)

    # the window's right edge: the last of its W columns, from the window's top left (the sum can pass the ring's end by
    # more than a page: not the BBC's "set the high byte to the ring's start")
    edge = "(RING_W - 1) * 8"
    p.block(410, 417, ["clc", "lda screen_start_address_low", "adc #$f8", "sta screen_address_low",
                       "lda screen_start_address_high", "adc #$00", "bpl skip_wraparound_138f", "lda #$60"],
            [p.call("start_plus_edge_sa", ring_add(START, SA, edge))])
    p.block(4778, 4785, ["clc", "lda screen_start_address_low", "adc #$f8", "sta edge_screen_address_low",
                         "lda screen_start_address_high", "adc #$00", "bpl plot_mines_on_screen_edge", "lda #$60"],
            [p.call("start_plus_edge_mines", ring_add(START, ("edge_screen_address_low", "edge_screen_address_high"),
                                                       edge))])
    # get_bottom_of_player_screen_address: four rows (a multiple of four rows is a whole number of pages)
    assert (4 * p.S) & 255 == 0
    p.imm(284, 0x04, (4 * p.S) >> 8, ops=("adc",))

    # move_player_down_four_pixels, not aligned: down a cell row
    p.block(2018, 2025, ["clc", "lda player_screen_address_high", "adc #$01", "bpl skip_wraparound_1e68", "sec",
                         "sbc #$20", "skip_wraparound_1e68:", "sta player_screen_address_high"],
            [p.call("psa_down", ring_add(PSA, PSA, S))])
    # check_if_completely_supported: two cell rows down
    p.block(2549, 2556, ["clc", "lda screen_address_high", "adc #$02", "bpl skip_wraparound_21e4", "sec", "sbc #$20",
                         "skip_wraparound_21e4:", "sta screen_address_high"],
            [p.call("sa_down2", ring_add(SA, SA, "2 * STRIDE"))])
    # the ground below a mine
    p.block(4271, 4280, ["lda screen_address_low", "sta ground_screen_address_low", "clc", "lda screen_address_high",
                         "adc #$01", "bpl skip_wraparound_2cfc", "sec", "sbc #$20", "skip_wraparound_2cfc:",
                         "sta ground_screen_address_high"],
            [p.call("ground_below", ring_add(SA, GROUND, S))])
    # scroll_down: the row that enters at the bottom is 31 rows below the top
    p.block(774, 783, ["lda screen_start_address_low", "sta screen_address_low", "clc", "lda screen_start_address_high",
                       "adc #$1f", "bpl skip_wraparound_1611", "sec", "sbc #$20", "skip_wraparound_1611:",
                       "sta screen_address_high"],
            [p.call("start_plus_31_rows", ring_add(START, SA, "31 * STRIDE"))])
    # plot_lift: four rows above the player
    p.block(814, 824, ["lda player_screen_address_low", "sta screen_address_low", "sec",
                       "lda player_screen_address_high", "sbc #$04", "cmp #$60", "bcs skip_wraparound_1658", "clc",
                       "adc #$20", "skip_wraparound_1658:", "sta screen_address_high"],
            [p.call("psa_up4", ring_add(PSA, SA, "-4 * STRIDE"))])
    # draw_map: ten rows below the window's top
    p.block(5357, 5366, ["lda screen_start_address_low", "sta map_screen_address_low", "clc",
                         "lda screen_start_address_high", "adc #$0a", "bpl skip_wraparound_3476", "sec", "sbc #$20",
                         "skip_wraparound_3476:", "sta map_screen_address_high"],
            [p.call("map_start", ring_add(START, MAP, "10 * STRIDE"))])
    # plot_map_tile: the next row
    p.block(5440, 5444, ["inc map_screen_address_high", "bpl skip_wraparound_34f2", "lda #$60",
                         "sta map_screen_address_high", "skip_wraparound_34f2:"],
            [p.call("map_down", ring_add(MAP, MAP, S))])
    # check_for_vertical_obstacle: from the last line of a cell to the first of the one below
    p.block(2643, 2652, ["clc", "lda screen_address_low", "adc #$f9", "sta screen_address_low",
                         "bcc check_for_vertical_obstacle_loop", "inc screen_address_high",
                         "bpl check_for_vertical_obstacle_loop", "lda #$60", "sta screen_address_high",
                         "jmp check_for_vertical_obstacle_loop"],
            [p.call("sa_next_group7", ring_add(SA, SA, "STRIDE - 7")), "    jmp check_for_vertical_obstacle_loop"])
    # plot_sprite: from the first line of a cell (8 on) back to the start of the group, and down a row
    p.block(1704, 1715, ["sec", "lda screen_address_low", "sbc #$08", "sta screen_address_low", "bcs skip_page_1c3e",
                         "dec screen_address_high", "skip_page_1c3e:", "inc screen_address_high",
                         "bpl plot_sprite_row_loop", "lda #$60", "sta screen_address_high",
                         "jmp plot_sprite_row_loop"],
            [p.call("sa_next_group8", ring_add(SA, SA, "STRIDE - 8")), "    jmp plot_sprite_row_loop"])
    # the tile column plots: down a cell row after each cell of a tile
    for first, lab in ((1292, "skip_wraparound_1985"), (1326, "skip_wraparound_19bc"), (1352, "skip_wraparound_19e6"),
                       (1383, "skip_wraparound_1a1d")):
        p.block(first, first + 4, ["inc screen_address_high", "bpl " + lab, "lda #$60", "sta screen_address_high",
                                   lab + ":"],
                [p.call("sa_down", ring_add(SA, SA, S))])
    # the player's plots: the next group of the column
    next_col = p.helper("col_next_group7", ring_add(COL, COL, "STRIDE - 7", rts=False) + """
    lda column_screen_address_low
    sta screen_address_low
    lda column_screen_address_high
    sta screen_address_high
    rts""")
    for first, label, wrap in ((6151, "plot_unflipped_player_row_loop", "skip_wraparound_3994"),
                               (6222, "plot_flipped_player_row_loop", "skip_wraparound_3a0e")):
        p.block(first, first + 12, ["sec", "lda column_screen_address_low", "sbc #$07", "sta column_screen_address_low",
                                    "sta screen_address_low", "inc column_screen_address_high", "bpl " + wrap,
                                    "lda #$60", "sta column_screen_address_high", wrap + ":",
                                    "lda column_screen_address_high", "sta screen_address_high", "jmp " + label],
                ["    jsr %s" % next_col, "    jmp " + label])
    # the flipped enemy: the same as plot_sprite's next group
    p.block(6316, 6327, ["sec", "lda screen_address_low", "sbc #$08", "sta screen_address_low", "bcs skip_page_3aa4",
                         "dec screen_address_high", "skip_page_3aa4:", "inc screen_address_high",
                         "bpl plot_flipped_enemy_row_loop", "lda #$60", "sta screen_address_high",
                         "jmp plot_flipped_enemy_row_loop"],
            [p.call("sa_next_group8", ring_add(SA, SA, "STRIDE - 8")), "    jmp plot_flipped_enemy_row_loop"])
    # vertical scrolling: the window and the player move by a row
    p.block(659, 672, ["dec screen_start_address_high", "lda screen_start_address_high", "cmp #$60",
                       "bcs skip_wraparound_screen_1541", "lda #$7f", "sta screen_start_address_high",
                       "skip_wraparound_screen_1541:", "dec player_screen_address_high",
                       "lda player_screen_address_high", "cmp #$60", "bcs skip_wraparound_player_154d", "lda #$7f",
                       "sta player_screen_address_high", "skip_wraparound_player_154d:"],
            [p.call("scroll_up_rows", ring_add(START, START, "-STRIDE", rts=False) + "\n" +
                    ring_add(PSA, PSA, "-STRIDE"))])
    p.block(744, 753, ["inc screen_start_address_high", "bpl skip_wraparound_screen_15d5", "lda #$60",
                       "sta screen_start_address_high", "skip_wraparound_screen_15d5:",
                       "inc player_screen_address_high", "bpl skip_wraparound_player_15dd", "lda #$60",
                       "sta player_screen_address_high", "skip_wraparound_player_15dd:"],
            [p.call("scroll_down_rows", ring_add(START, START, "STRIDE", rts=False) + "\n" +
                    ring_add(PSA, PSA, "STRIDE"))])
    p.block(6958, 6964, ["dec screen_start_address_high", "lda screen_start_address_high", "cmp #$60",
                         "bcs skip_wraparound_3ee7", "lda #$7f", "sta screen_start_address_high",
                         "skip_wraparound_3ee7:"],
            [p.call("start_up", ring_add(START, START, "-STRIDE"))])
    # up four lines from a cell's first line: into the cell above (a cell row less four lines)
    p.block(2085, 2090, ["sec", "lda player_screen_address_low", "sbc #$fc", "sta player_screen_address_low",
                         "jsr get_player_screen_address_high_after_subtraction", "sta player_screen_address_high"],
            [p.call("psa_up4lines", ring_add(PSA, PSA, "-(STRIDE - 4)"))])
    p.block(2686, 2690, ["sec", "lda player_screen_address_low", "sbc #$fc", "sta screen_address_low",
                         "jsr get_player_screen_address_high_after_subtraction"],
            [p.call("psa_up4lines_sa", ring_add(PSA, SA, "-(STRIDE - 4)", rts=False) +
                    "\n    lda screen_address_high\n    rts")])
    # find_hold_on_rope: the player moves up y_fraction rows
    p.block(2736, 2744, ["sec", "lda player_screen_address_high", "sbc y_fraction", "cmp #$60",
                         "bcs skip_wraparound_2314", "clc", "adc #$20", "skip_wraparound_2314:",
                         "sta player_screen_address_high"],
            [p.call("psa_up_y_fraction", """    lda y_fraction
    jsr %s
    sec
    lda player_screen_address_low
    sbc c64_t0
    sta player_screen_address_low
    lda player_screen_address_high
    sbc c64_t1
    cmp #RING_HI
    bcs @ok
    adc #RING_SZ_HI
@ok:
    sta player_screen_address_high
    rts""" % rows)])


def whole(p):
    rows = rows_helper(p)
    # tile row (a multiple of four cell rows) as the high byte: tile_y * 4 * STRIDE / 256
    tiley = p.helper("tiley_hi", """    lda wide_tiley_hi_table,y
    rts
wide_tiley_hi_table:
%s""" % "\n".join("    .byte (%d * 4 * STRIDE) >> 8" % k for k in range(8)))
    p.block(4026, 4029, ["tya", "asl a", "asl a", "sta enemy_y"], ["    jsr %s" % tiley, "    sta enemy_y"])

    # calculate_screen_address: X = x (cells), Y = y (lines) -> screen_address = start + (y >> 3) * STRIDE + x * 8 + (y & 7)
    calc = p.helper("calc_screen_address", """    tya
    lsr
    lsr
    lsr
    jsr %s                      ; c64_t1:c64_t0 = (y / 8) strides
    tya
    and #7
    clc
    adc c64_t0
    sta c64_t0
    bcc @1
    inc c64_t1
@1:
    txa                         ; + x * 8 (16 bits: x may be 32 or more)
    sta c64_t2
    lda #0
    sta c64_t3
    asl c64_t2
    rol c64_t3
    asl c64_t2
    rol c64_t3
    asl c64_t2
    rol c64_t3
    clc
    lda c64_t0
    adc c64_t2
    sta c64_t0
    lda c64_t1
    adc c64_t3
    sta c64_t1
    clc                         ; + the window's top left
    lda c64_t0
    adc screen_start_address_low
    sta screen_address_low
    lda c64_t1
    adc screen_start_address_high
    cmp #$80
    bcc @ok
    sbc #RING_SZ_HI
@ok:
    sta screen_address_high
    lda screen_address_low
    rts""" % rows)
    p.block_hash(5837, 5863, "a524ab1477cf", ["    jmp %s" % calc])

    # calculate_player_screen_address_offset: X = the player's row in the window ((psa - start - 1) / STRIDE)
    poff = p.helper("player_offset", """    sec                         ; (what the BBC's code leaves in minus_offset)
    lda screen_start_address_low
    sbc player_screen_address_low
    sta minus_offset_low
    lda screen_start_address_high
    sbc player_screen_address_high
    sta minus_offset_high
    cmp #RING_SZ_HI             ; (the BBC's code: the player's address is always above the window's top left; if it is
    bcs @go                     ; the same, it leaves X and Y as they are)
    rts
@go:
    sec                         ; d = psa - start - 1, modulo the ring
    lda player_screen_address_low
    sbc screen_start_address_low
    sta c64_t0
    lda player_screen_address_high
    sbc screen_start_address_high
    sta c64_t1
    sec
    lda c64_t0
    sbc #1
    sta c64_t0
    lda c64_t1
    sbc #0
    bcs @pos
    adc #RING_SZ_HI
@pos:
    sta c64_t1
.if RING_W = 32
    ldx c64_t1                  ; d / 256
.else
    lsr c64_t1                  ; the cell: d / 8, then its row by table
    ror c64_t0
    lsr c64_t1
    ror c64_t0
    lsr c64_t1
    ror c64_t0
    lda c64_t0
    sta zp_u
    lda c64_t1
    clc
    adc #>ROWTAB
    sta zp_u+1
    ldy #0
    lda (zp_u),y
    tax
.endif
    txa
    eor #$ff
    tay                         ; Y = $ff - X
    clc
    adc #$20                    ; A = Y + $20
    rts""")
    p.block_hash(6029, 6047, "5531f9aca6ff", ["    jmp %s" % poff])

    # replot_tile: the screen address of a tile at relative tile x = Y, in the window
    replot = p.helper("replot_address", """    tya
    asl
    asl
    sec
    sbc $78                     ; tile_x_fraction: cells
    sta c64_t0
    lda #0
    sta c64_t1
    asl c64_t0                  ; * 8: 16 bits
    rol c64_t1
    asl c64_t0
    rol c64_t1
    asl c64_t0
    rol c64_t1
    lda $7b                     ; tile_y: * 4 rows * STRIDE / 256
%s
    clc
    adc c64_t1
    sta c64_t1
    clc
    lda c64_t0
    adc screen_start_address_low
    sta screen_address_low
    lda c64_t1
    adc screen_start_address_high
    cmp #$80
    bcc @ok
    sbc #RING_SZ_HI
@ok:
    sta screen_address_high
    rts""" % TILEY_A)
    p.block_hash(5697, 5720, "8290022fc934", ["    jsr %s" % replot])

    # a skeleton's graphics are drawn X groups (cell rows) below the enemy's address (X = 1, 2 or 3; X and Y are kept)
    down_x = p.helper("sa_down_x", """    txa
    jsr %s                      ; c64_t1:c64_t0 = X strides
    clc
    lda screen_address_low
    adc c64_t0
    sta screen_address_low
    lda screen_address_high
    adc c64_t1
    cmp #$80
    bcc @ok
    sbc #RING_SZ_HI
@ok:
    sta screen_address_high
    rts""" % rows)
    p.block(3840, 3847, ["txa", "clc", "adc screen_address_high", "bpl skip_wraparound_2a33", "sec", "sbc #$20",
                         "skip_wraparound_2a33:", "sta screen_address_high"],
            ["    jsr %s" % down_x])
    # a mine at the edge: its address from its row (mines_y / 8 = group) and line in the group
    mine = p.helper("mine_address", """    lda group
    jsr %s                      ; c64_t1:c64_t0 = group strides
    clc
    lda c64_t0
    adc row_in_group
    sta c64_t0
    bcc @1
    inc c64_t1
@1:
    clc
    lda c64_t0
    adc edge_screen_address_low
    sta screen_address_low
    lda c64_t1
    adc edge_screen_address_high
    cmp #$80
    bcc @ok
    sbc #RING_SZ_HI
@ok:
    sta screen_address_high
    rts""" % rows)
    p.block_hash(4805, 4815, "b88b7b44cce6", ["    jsr %s" % mine])

    # an enemy's blaster: where it starts, from the enemy's row (tile_y * 4 + 1 rows) and column (relative x)
    eoff = p.helper("enemy_blaster_offset", """    lda enemy_relative_x       ; x * 8: 16 bits
    sta c64_t0
    lda #0
    sta c64_t1
    asl c64_t0
    rol c64_t1
    asl c64_t0
    rol c64_t1
    asl c64_t0
    rol c64_t1
    clc                         ; + one row
    lda c64_t0
    adc #<STRIDE
    sta c64_t0
    lda c64_t1
    adc #>STRIDE
    sta c64_t1
    lda enemy_tile_y            ; + tile_y * 4 rows
%s
    clc
    adc c64_t1
    sta blaster_offset_high
    lda c64_t0
    sta blaster_offset_low
    rts""" % TILEY_A)
    p.block_hash(4364, 4374, "cb3e932778ea", ["    jsr %s" % eoff])
    # ... and its adjustments (at 32 columns the BBC's code loses the carry: kept, so as to be the BBC's)
    badd = p.helper("blaster_add_1d", """.if RING_W = 32
    clc
    lda blaster_offset_low
    adc #$1d
.else
    clc
    lda blaster_offset_low
    adc #$1d
    sta blaster_offset_low
    bcc @1
    inc blaster_offset_high
@1:
.endif
    rts""")
    p.block_hash(4383, 4386, "1ae354f5c823", ["    jsr %s" % badd, "    jmp add_enemy_blaster"])
    bsub = p.helper("blaster_sub_3", """.if RING_W = 32
    sec
    lda blaster_offset_low
    sbc #$03
.else
    sec
    lda blaster_offset_low
    sbc #$03
    sta blaster_offset_low
    bcs @1
    dec blaster_offset_high
@1:
.endif
    rts""")
    p.block(4393, 4395, ["sec", "lda blaster_offset_low", "sbc #$03"], ["    jsr %s" % bsub])

    # update_blaster: a blaster is removed at the window's left and right edges (the first column of the window, or the
    # one past the last). The BBC compares the low byte of its address with the window's: the same column mod 32.
    edge = p.helper("blaster_at_edge", """.if RING_W = 32
    lda blasters_screen_address_low,x
    and #$f8
    cmp screen_start_address_low
.else
    sec                         ; d = blaster - window top left, modulo the ring: the cell's column by table
    lda blasters_screen_address_low,x
    sbc screen_start_address_low
    sta c64_t0
    lda blasters_screen_address_high,x
    sbc screen_start_address_high
    bcs @pos
    adc #RING_SZ_HI
@pos:
    lsr
    ror c64_t0
    lsr
    ror c64_t0
    lsr
    ror c64_t0
    sta c64_t1
    lda c64_t0
    sta zp_u
    lda c64_t1
    clc
    adc #>COLTAB
    sta zp_u+1
    ldy #0
    lda (zp_u),y                ; the column: Z if it is the first
.endif
    rts""")
    p.block(6705, 6708, ["lda blasters_screen_address_low,x", "and #$f8", "cmp screen_start_address_low",
                         "beq remove_blaster"],
            ["    jsr %s" % edge, "    beq remove_blaster"])


TILEY_A = """.if RING_W = 32
    asl
    asl
.else
    sta c64_t2
    asl
    asl
    clc
    adc c64_t2                  ; tile_y * 5 = tile_y * 4 * 320 / 256
.endif"""


# ------------------------------------------------------------------------------------------------------------------
def tables(p):
    """The tables of 16-bit offsets from the player's address, made again for the ring's geometry (the BBC's, which have
    other users, are left as they are) and the code pointed at them."""
    lines = p.src_lines_of("src/data.s")

    def table(label, n):
        i = [k for k, l in enumerate(lines) if l.startswith(label + ":")][0]
        vals = []
        for l in lines[i + 1:]:
            m = re.match(r"\s+\.byte (\$[0-9a-f]{2}),(\$[0-9a-f]{2})", l)
            if not m:
                break
            vals.append((int(m.group(1)[1:], 16), int(m.group(2)[1:], 16)))
            if len(vals) == n:
                break
        return vals

    def cooked(pairs):
        out = []
        for lo, hi in pairs:
            r, c, l = decompose(hi * 256 + lo)
            out.append(p.off16(r, c, l))
        return out

    # kneeling_check_offsets: (low, high) pairs, used together
    kco = cooked(table("kneeling_check_offsets", 8))
    body = "\n".join("    .byte $%02x, $%02x" % pr for pr in kco)
    name = p.helper("kneeling_check_offsets", "wide_kneeling_check_offsets_data:\n" + body)
    # the helper is data, not code: name it so the code can refer to it
    p.replace_line(2773, r"lda kneeling_check_offsets,x$", "    lda wide_kneeling_check_offsets_data,x")
    p.replace_line(2778, r"adc \$0571,x$", "    adc wide_kneeling_check_offsets_data+1,x")

    # the player's points (collision with blasters): the BBC uses the low byte of the stance's table and the high byte of
    # the standing table (a bug, kept)
    standing = table_from_source(p, "standing_point_offsets")
    kneeling = table_from_source(p, "kneeling_point_offsets")
    crawling = table_from_source(p, "crawling_point_offsets")
    names = {}
    for nm, tab in (("standing", standing), ("kneeling", kneeling), ("crawling", crawling)):
        lo_new, hi_used = [], []
        for (lo, _hi), (_lo2, st_hi) in zip(tab, standing):
            r, c, l = decompose(st_hi * 256 + lo)        # the offset actually used: the standing table's high byte
            nlo, nhi = p.off16(r, c, l)
            lo_new.append(nlo)
            hi_used.append(nhi)
        names[nm] = (lo_new, hi_used)
    his = names["standing"][1]
    for nm in ("kneeling", "crawling"):
        if names[nm][1] != his:
            raise Edit("the player's point tables do not share their high bytes in the %d-column ring" % p.W)
    body = "wide_standing_point_offsets:\n" + "\n".join(
        "    .byte $%02x, $%02x" % (lo, hi) for lo, hi in zip(names["standing"][0], his))
    # (the same pair layout: the code indexes them by 0, 2, 4, 6)
    body += "\nwide_kneeling_point_lo:\n" + "\n".join("    .byte $%02x, $%02x" % (lo, hi) for lo, hi in zip(names["kneeling"][0], his))
    body += "\nwide_crawling_point_lo:\n" + "\n".join("    .byte $%02x, $%02x" % (lo, hi) for lo, hi in zip(names["crawling"][0], his))
    p.helper("player_point_offsets", body)
    p.replace_line(4491, r"lda standing_point_offsets,x$", "    lda wide_standing_point_offsets,x")
    p.replace_line(4496, r"lda kneeling_point_offsets,x$", "    lda wide_kneeling_point_lo,x")
    p.replace_line(4501, r"lda crawling_point_offsets,x$", "    lda wide_crawling_point_lo,x")
    p.replace_line(4507, r"adc \$2e7f,x$", "    adc wide_standing_point_offsets+1,x")


def table_from_source(p, label):
    i = [k for k, l in enumerate(p.L) if l.startswith(label + ":")][0]
    vals = []
    for l in p.L[i + 1:]:
        m = re.match(r"\s+\.byte (\$[0-9a-f]{2}),(\$[0-9a-f]{2})", l)
        if not m:
            break
        vals.append((int(m.group(1)[1:], 16), int(m.group(2)[1:], 16)))
    return vals


# ------------------------------------------------------------------------------------------------------------------
def semantic(p):
    """What the 32 columns of the BBC's window mean in the code: where it starts to scroll, where an enemy is cropped, the
    columns at its edges, the positions the game starts from."""
    W = p.W
    half = W // 2
    # consider_scrolling_right / left: the window scrolls while the player is in the middle of the level (x from W/2 on)
    p.imm(373, 0x0f, "RING_W / 2 - 1", ops=("cmp",))
    p.imm(377, 0xef, "255 - RING_W / 2", ops=("cmp",))
    p.imm(543, 0x10, "RING_W / 2", ops=("cmp",))
    p.imm(547, 0xf0, "256 - RING_W / 2", ops=("cmp",))
    # the window is RING_W / 4 tiles wide: a row of tiles (the vertical scroll), and replot_tile's test of whether a tile is
    # in it
    p.imm(1490, 0x08, "RING_W / 4", ops=("cmp",))
    p.imm(5657, 0x08, "RING_W / 4", ops=("adc",))
    p.imm(5689, 0x08, "RING_W / 4", ops=("cpy",))
    # the column at the window's right edge (a star, an object coming into view)
    p.imm(436, 0x1f, "RING_W - 1", ops=("ldx",))
    p.imm(2887, 0x1f, "RING_W - 1", ops=("ldx",))
    # an enemy's position relative to the window's left edge: fully visible below W - 4, cropped below W, off the right
    p.imm(3625, 0x1c, "RING_W - 4", ops=("cmp",))
    p.imm(3627, 0x20, "RING_W", ops=("cmp",))
    p.imm(3682, 0x1c, "RING_W - 4", ops=("sbc",))
    p.imm(3722, 0x1c, "RING_W - 4", ops=("cmp",))
    p.imm(4344, 0x20, "RING_W", ops=("cmp",))
    # the lift at the right end of a level is W - 8 columns from the window's left edge, the left one 4
    p.imm(869, 0x18, "$18 + RING_W - 32", ops=("ldy",))
    p.imm(873, 0x1b, "$1b + RING_W - 32", ops=("ldy",))
    p.imm(924, 0x19, "$19 + RING_W - 32", ops=("ldy",))
    p.imm(969, 0x19, "$19 + RING_W - 32", ops=("ldy",))
    # the window's right edge (in level columns) is its left + W - 4
    for n in (3932, 6464):
        p.imm(n, 0x1c, "RING_W - 4", ops=("lda",))
    p.imm(5034, 0xa8, "$a8 + RING_W - 32", ops=("lda",))          # the status screen: the picture ends at that column
    p.imm(7130, 0x7c, "$7c + RING_W - 32", ops=("lda",))          # the completion screen
    # the title: the scroll through DROID leaves the window at column 140 (the player's x counts from 13, and the window
    # starts to move at x = W / 2 - 1), and the scroll onto the first level leaves the player at x = 196
    p.imm(5069, 0x8e, "$8e + (RING_W - 32) / 2", ops=("lda",))
    p.imm(5168, 0x29, "$29 - (RING_W - 32) / 2", ops=("lda",))
    # the title's scroll leaves the corner tile set ($40) in place for the logo (c64_scroll_delay changes it for the last
    # steps, whose columns the title does not show)
    # and the window is W - 32 columns wider than the BBC's, so the columns the BBC's scroll draws first (32 to W - 1)
    # are in the window at the start: they are drawn here, in the window's blank columns, with the scroll's own steps
    # (right edge back to column 31, then one column at a time), before the scroll starts
    prefill = """    sec
    lda right_edge_tile_address_low
    sbc #(RING_W - 32)
    sta right_edge_tile_address_low
    bcs @t1
    dec right_edge_tile_address_high
@t1:
    ldy #32
@col:
    inc right_edge_x_fraction
    lda right_edge_x_fraction
    cmp #4
    bne @t2
    lda #0
    sta right_edge_x_fraction
    clc
    lda right_edge_tile_address_low
    adc #4
    sta right_edge_tile_address_low
    bcc @t2
    inc right_edge_tile_address_high
@t2:
    tya
    asl
    asl
    asl                         ; 8 bytes a column: y * 8 (at most 39 * 8: two bytes)
    sta zp_t
    lda #0
    rol
    sta zp_t + 1
    clc
    lda screen_start_address_low
    adc zp_t
    sta screen_address_low
    lda screen_start_address_high
    adc zp_t + 1
    bpl @t3
    sbc #(RING_SZ_HI - 1)       ; (carry is clear: this subtracts RING_SZ_HI)
@t3:
    sta screen_address_high
    lda right_edge_x_fraction
    sta $77                     ; tile_x_fraction
    lda right_edge_tile_address_low
    sta $74                     ; tile_address_low
    lda right_edge_tile_address_high
    sta $75                     ; tile_address_high
    tya
    pha
    jsr plot_column_of_tiles
    pla
    tay
    iny
    cpy #RING_W
    bne @col
""" if W > 32 else ""
    p.replace_line(5077, r"jsr scroll_right_for_count$", p.call("title_scroll", prefill + """    jsr scroll_right_for_count
    lda #$40                    ; (use corner tiles)
    sta level_sprite_base
    rts"""))
    # (the window's top left and the player's address at the start of the game: from where the title's scrolls end)
    s_start = 181 - (W - 32) // 2
    S = p.S
    psa = p.RING + s_start * 8 + 15 * S + (half - 1) * 8 + 4
    p.abs_pair(5190, 5192, 0x7524, psa)
    # the player on the title screen: 18 rows and 14 cells into the window that the scroll leaves at cell 140
    p.abs_pair(5125, 5127, 0x76d0, p.RING + 140 * 8 + 18 * S + 14 * 8)
    # losing a life on the left of a level: the player 12 rows down and 4 cells in
    p.abs_pair(3936, 3934, 0x6c20, p.RING + 12 * S + 4 * 8)
    # losing a life at the right end (in the lift): the window starts 7 rows down; the player is 19 rows down, W - 8 cells in
    right_lift = """    lda #<(RING + 7 * STRIDE)
    sta screen_start_address_low
    lda #0
    sta player_direction                    ; (facing right)
    lda #>(RING + 7 * STRIDE)
    sta screen_start_address_high
    lda #>(RING + 19 * STRIDE + (RING_W - 8) * 8)
    sta player_screen_address_high
    lda #<(RING + 19 * STRIDE + (RING_W - 8) * 8)
    sta player_screen_address_low
    lda #<(256 - RING_W)
    sta left_edge_tile_address_low
    lda #$fc
    sta right_edge_tile_address_low
    lda #<(7 * RING_W)
    sta crtc_address_low
    lda #CRTC_HI + >(7 * RING_W)
    sta crtc_address_high
    rts"""
    p.block(3911, 3925, ["lda #$00", "sta screen_start_address_low", "sta player_direction", "lda #$67",
                         "sta screen_start_address_high", "lda #$73", "sta player_screen_address_high", "lda #$c0",
                         "sta player_screen_address_low", "lda #$e0", "sta left_edge_tile_address_low", "lda #$fc",
                         "sta right_edge_tile_address_low", "lda #$e0", "sta crtc_address_low"],
            [p.call("right_lift_start", right_lift)])
