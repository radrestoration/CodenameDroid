#!/usr/bin/env python3
"""Make the C64's copy of the game source from the BBC source in bbc/src.

    make_game_source.py OUTDIR

The game logic is the original, unchanged. This applies a short, explicit list of
patches (each asserted to match exactly once) for the places where the BBC and the C64
differ: the zero-page bytes $00-$03 (the C64's CPU port is at $00/$01), the few
hardware accesses (CRTC, VIA, ULA), the OS calls (which become small shims), and the
OS ROM used as a random table. Everything that draws on the screen is NOT patched
here: the screen buffer at &6000-&7fff is the original one, and src/cells.s turns
changed cells of it into characters.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
SRC = os.path.join(HERE, "..", "bbc", "src")

ZP_MOVE = 0xe4            # $00-$03 (enemy_variables and everything aliased on them) -> $e4-$e7

# The width of the game's window in cells, which is also the row length of its screen buffer ("the ring"): the BBC's
# 32, or 40 to fill the C64's screen. WIDE=40 is the default: see C64-README.md.
WIDE = int(os.environ.get("WIDE", "32"))
assert WIDE in (32, 40), WIDE
# WIDE_PATCH=1 applies the geometry patches also at 32 columns (the tests use that to show the patches keep the game
# as it was: the build must then behave exactly as the BBC's)
FORCE = bool(int(os.environ.get("WIDE_PATCH", "0")))


def sub_once(text, old, new, what):
    n = text.count(old)
    if n != 1:
        raise SystemExit("patch %r: %d matches" % (what, n))
    return text.replace(old, new)


def symbols(text):
    out = []
    for line in text.split("\n"):
        m = re.match(r"^(\w+)(\s*)= \$([0-9a-f]+)(.*)$", line)
        if m:
            name, sp, val, rest = m.groups()
            v = int(val, 16)
            if v < 4:
                line = "%s%s= $%02x%s" % (name, sp, ZP_MOVE + v, rest)
            elif name in ("OSBYTE", "OSWORD", "OSWRCH", "OSRDCH", "OSCLI"):
                line = "%s%s= c64_%s%s" % (name, sp, name.lower(), rest)
        out.append(line)
    return "\n".join(out)


def game(text):
    t = text
    t = sub_once(t, "    lda $fe62                        ; User VIA data direction register B",
                 "    lda c64_via_ddr_b                ; (BBC: User VIA data direction register B)", "fe62")
    t = sub_once(t, "    lda $e400,y ", "    lda star_random,y ", "OS ROM random table")
    # screen start address: remember it instead of writing the CRTC
    t = sub_once(t, """    lda #$0c                         ; R12: Displayed screen start address register (high)
    sta $fe00                        ; video register number
    lda crtc_address_high
    sta $fe01                        ; video register value
    lda #$0d                         ; R13: Displayed screen start address register (low)
    sta $fe00                        ; video register number
    lda crtc_address_low
    sta $fe01                        ; video register value
    rts""", """    lda crtc_address_high            ; (BBC: CRTC R12/R13)
    sta c64_crtc_high
    lda crtc_address_low
    sta c64_crtc_low
    .res 10, $ea                     ; the BBC's 20 bytes, so that no address after this moves
    rts""", "set_crtc_address")
    # video off / on around display_level (CRTC R8)
    t = sub_once(t, """display_level:
    lda #$08                         ; R8: Interlace and delay register
    sta $fe00                        ; video register number
    lda #$30                         ; Disable video output
    sta $fe01                        ; video register value
""", """display_level:
    jsr c64_video_off                ; (BBC: CRTC R8 = &30, disable video output)
    .res 7, $ea
""", "display_level video off")
    t = sub_once(t, """    lda #$08                         ; R8: Interlace and delay register
    sta $fe00                        ; video register number
    lda #$00                         ; Enable video output
    sta $fe01                        ; video register value
    rts""", """    jmp c64_video_on                 ; (BBC: CRTC R8 = 0, enable video output)
    .res 8, $ea""", "display_level video on")
    assert t.count("lda $fe64") == 2
    t = t.replace("lda $fe64                        ; User VIA timer 1 counter LSB",
                  "lda $dc04                        ; (BBC: User VIA timer 1 counter LSB) CIA 1 timer A")
    # zero page $00/$01 as tile_address / name_address pointers, and the wipe of &0000-&009f
    t = sub_once(t, """initialise_variables:
    ldx #$00
    txa
wipe_0000_to_009f_loop:
    sta $00,x                        ; Wipe &0000 - &009f
    inx
    cpx #$a0
""", """initialise_variables:
    jsr c64_wipe_enemy_zp            ; (BBC: ldx #0 / txa) clears $e4-$e7, the BBC's &00-&03; leaves X = A = 0
wipe_0000_to_009f_loop:
    sta $02,x                        ; Wipe &0002 - &009f
    inx
    cpx #$9e
""", "wipe zero page")
    # numeric zero-page operands $00-$03 (tile_address, tile_x, tile_y, ...) move with the rest;
    # the indexed `$01,x` (enemies array offset) and the wipe loop's `$00,x` are not variables
    t = re.sub(r"^(\s+[a-z]{3}\s+\(?)\$0([0-3])(\)?(?:,y)?)(?=[ \n])",
               lambda m: "%s$%02x%s" % (m.group(1), ZP_MOVE + int(m.group(2)), m.group(3)), t, flags=re.M)
    # nothing may still use $00-$03 as a variable (`$01,x` in the enemies array code and the
    # wipe loop's `$00,x` are indexed, not the variables)
    for m in re.finditer(r"^\s+[a-z]{3}\s+\(?\$0[0-3]\b[^;\n]*", t, re.M):
        if not m.group(0).strip().startswith(("sta $01,x", "sta $02,x")):   # array offsets
            raise SystemExit("unpatched use of $00-$03: %r" % m.group(0))
    # scrolling right: the entering column is drawn, then the game waits for the vertical retrace and only then
    # moves the display start (the BBC's CRTC latches it just after the retrace, so the picture and the start
    # address change together). Presenting at the wait would show the new column with the old start (a stray
    # column at the left edge, every frame): wait now, present once the start and the edge objects are done.
    t = sub_once(t, "    jsr wait_for_vsync\nskip_waiting_for_sync:\n",
                 "    jsr c64_wait_deferred            ; (BBC: jsr wait_for_vsync)\nskip_waiting_for_sync:\n", "scroll right wait")
    t = sub_once(t, "    jsr update_jet_pack\nskip_scrolling_screen_right:\n",
                 "    jsr c64_scroll_end               ; (BBC: jsr update_jet_pack)\nskip_scrolling_screen_right:\n", "scroll right end")
    # the title scroll runs with interrupts off on the BBC (sei ... cli); the C64's raster interrupt counts the frames
    # the waits use and scans the keys, so it must stay on (the same one byte each)
    t = sub_once(t, "scroll_right_for_count:\n    sei\n", "scroll_right_for_count:\n    nop                              ; (BBC: sei)\n", "sei")
    t = sub_once(t, "    bne scroll_right_for_count_loop\n    cli\n", "    bne scroll_right_for_count_loop\n    nop                              ; (BBC: cli)\n", "cli")
    # the title scroll's own delay per step (a busy-wait that paces the BBC's scroll; the C64's waits pace it)
    t = sub_once(t, "scroll_right_for_count_loop:\n    jsr delay\n", "scroll_right_for_count_loop:\n    jsr c64_scroll_delay             ; (BBC: jsr delay)\n", "scroll delay")
    t = hooks(t)
    return t


def hooks(t):
    """Entry hooks on the routines that draw into the screen buffer (platform.s). Each replaces the
    first four bytes of the routine with a JMP and a spare byte, so nothing moves; the hook runs
    the displaced instructions itself and calls the rest of the routine at the new label."""
    def hook(label, displaced, jump, body_label=None):
        nonlocal t
        old = label + ":\n" + displaced
        new = label + ":\n    jmp " + jump + "\n    .byte $ea\n"
        if body_label:
            new += body_label + ":\n"
        t = sub_once(t, old, new, "hook " + label)
    hook("plot_sprite_skipping_offset", "    stx width\n    sty height\n", "c64_hook_sprite", "plot_sprite_body")
    hook("plot_flipped_enemy", "    stx width\n    sty height\n", "c64_hook_fenemy", "plot_flipped_enemy_body")
    hook("plot_unflipped_player", "    stx width\n    sty height\n", "c64_hook_uplayer", "plot_unflipped_player_body")
    hook("plot_flipped_player", "    stx width\n    sty height\n", "c64_hook_fplayer", "plot_flipped_player_body")
    hook("plot_column_of_tiles", "    lda #$00\n    sta $76                          ; tile_y\n", "c64_hook_column")
    hook("plot_row_of_tiles", "    lda #$00\n    sta $76                          ; tile_x\n", "c64_hook_row")
    # variable_delay: the BBC busy-waits delay_length to pace each scroll step; the C64 build is paced
    # by the frame (and the delay would cost 12,000 cycles a step). Same two bytes.
    t = sub_once(t, "variable_delay:\n    lda #$00\n    sta count_low\n",
                 "variable_delay:\n    rts                              ; (BBC: a busy-wait to pace the scrolling)\n    .byte $ea\n    sta count_low\n",
                 "variable_delay")
    # update_chandeliers scans the whole 256-byte level page for chandelier tiles every few frames (14,000
    # cycles; the BBC has twice the clock): c64_update_chandeliers does the same, faster
    t = sub_once(t, "update_chandeliers:\n    lda left_edge_tile_address_high\n    sta $e5                          ; tile_address_high\n",
                 "update_chandeliers:\n    jmp c64_update_chandeliers       ; (BBC: lda left_edge_tile_address_high / sta tile_address_high)\n    .byte $ea\n",
                 "update_chandeliers")
    # which screen is up, for the vertical camera (platform.s): gameplay follows the player, every other
    # screen (title, status screens, game over) uses the default view
    t = sub_once(t, "    lda c64_via_ddr_b                ; (BBC: User VIA data direction register B)",
                 "    jsr c64_game_mode                ; (BBC: lda User VIA DDRB) - also notes that gameplay is running", "game mode")
    t = sub_once(t, "title_screen:\n    jsr reset_tiles\n", "title_screen:\n    jsr c64_title_mode               ; (BBC: jsr reset_tiles)\n", "title mode")
    t = sub_once(t, "prepare_status_screen:\n    jsr set_colour_zero_to_black\n",
                 "prepare_status_screen:\n    jsr c64_status_mode              ; (BBC: jsr set_colour_zero_to_black)\n", "status mode")
    t = sub_once(t, "to_game_over_screen:\n    jmp game_over_screen\n", "to_game_over_screen:\n    jmp c64_gameover_mode            ; (BBC: jmp game_over_screen)\n", "game over mode")
    # the star: lda #$88 / sta (screen_address),y  ->  jsr + nop
    t = sub_once(t, "    lda #$88                         ; 3000\n    sta (screen_address),y           ; Plot star\n",
                 "    jsr c64_star_store               ; (BBC: lda #$88 / sta (screen_address),y)\n    nop\n", "star")
    # clear_screen: the same 19 bytes
    t = sub_once(t, """clear_screen:
    lda #$60
    sta screen_address_high
    lda #$00
    sta screen_address_low
    tay
clear_screen_loop:
    sta (screen_address),y           ; Wipe &6000 - &7fff
    iny
    bne clear_screen_loop
    inc screen_address_high
    bpl clear_screen_loop
    rts
""", """clear_screen:
    jmp c64_clear_screen             ; (BBC: wipe &6000-&7fff; here also its characters)
    .res 16, $ea
""", "clear_screen")
    return t


def data(text):
    """data.s for this geometry: with the wide ring the tile graphics (the block at $5800) are at TILES, and the
    addresses in tile_sprites_addresses_table follow (the high byte of each, kept as 'TILES + (old - $5800)')."""
    if WIDE == 32:
        return text
    lines = text.split("\n")
    counts = {}
    for table, expect in (("tile_sprites_addresses_table", 19), ("player_sprite_addresses_table", 6)):
        start = [i for i, l in enumerate(lines) if l.startswith(table + ":")][0]
        n = 0
        for i in range(start + 1, len(lines)):
            m = re.match(r"^(\s+\.byte )\$([0-9a-f]{2}),\$([0-9a-f]{2})(.*)$", lines[i])
            if not m:
                break
            hi = int(m.group(3), 16)
            if 0x58 <= hi <= 0x5f:
                lines[i] = "%s$%s,>TILES + $%02x%s" % (m.group(1), m.group(2), hi - 0x58, m.group(4))
                n += 1
        assert n == expect, (table, n)               # the entries that point into the tile block
    return "\n".join(lines)


def main(outdir):
    os.makedirs(outdir, exist_ok=True)
    rd = lambda n: open(os.path.join(SRC, n)).read()
    open(os.path.join(outdir, "params.inc"), "w").write("; made by make_game_source.py\nRING_W = %d\n" % WIDE)
    open(os.path.join(outdir, "symbols_c64.inc"), "w").write(symbols(rd("symbols.inc")))
    import wide_patches
    text, helpers = wide_patches.apply(rd("droid.s"), WIDE, FORCE)
    open(os.path.join(outdir, "game.s"), "w").write(game(text))
    open(os.path.join(outdir, "ring_ops.s"), "w").write("; made by make_game_source.py: helpers the geometry patches call\n" + helpers + "\n")
    open(os.path.join(outdir, "data.s"), "w").write(data(rd("data.s")))
    import make_tables
    make_tables.main(os.path.join(outdir, "tables.s"))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
