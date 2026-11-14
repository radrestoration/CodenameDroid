; Apple IIgs display layer: the game logic's picture in Super Hi-Res (320 x 200, 4 bits a pixel; the BBC's four colours are palette
; entries 0 - 3). The logic stages a 40 x 25 matrix of character numbers, the characters' BBC bytes (BPAT) and up to 8 C64 hardware
; sprites; this layer draws them. The platform (platform.s) calls, with JSL from emulation mode:
;   shr_init          once, first: zero the layer's tables and state, shadow bank 1 into $E1
;   shr_present       show the staged picture; shr_present_hold: the matrix only, the sprite registers as last latched
;   shr_char_hook     (through the platform's entry table) the logic wrote character Y into BPAT
; and it switches to native mode for its work and back before returning (A, X, Y, flags are not preserved).
;
; The picture is kept in bank 1 $2000-$9CFF (fast RAM); every write there is also made in bank $E1 by the hardware (shadow
; register bit 3 clear), so the slow memory is never read. A shadow copy of the matrix says which cells differ; characters are
; converted from BPAT to 8 x 4 byte cells (`shrchars`, through `bbc2shr`) when shr_char_hook says they changed; when the window
; moves by one cell the picture is shifted (a stack slam, slam_right / slam_down, for the directions that allow it) and only the
; new edge is drawn; any other jump redraws everything. Sprites are composed off-screen (`shrbuf`) with the cells they cover, and
; each cell is written once, so a sprite never disappears between being erased and drawn.
;
; Not here yet: the fine scroll (t_xs).
.p816
.smart +
.include "logic_syms.inc"
.import bbc2shr, shrchars, shadow, dirty, shadowmat, cellscr, splist, spstate, splatch, chdirty, edgebuf, slam_save, ulist, cellmark, incell, shrbuf
.export shr_init, shr_present, shr_present_hold, shr_char_hook, slam_right, slam_down

LOGIC_DEFAULT = $000000
.ifndef LOGIC
LOGIC   = LOGIC_DEFAULT         ; where the logic's 64 KB lives: bank 0 in the display test, bank 2 in the game (-D LOGIC=$020000)
.endif
HALDP   = $0700                 ; the layer's own direct page (bank 0, unused by the C64 layout)
SCREEN  = $2000
LINE    = 160
CELLS   = 40 * 25

.segment "ZEROPAGE"             ; offsets within the layer's direct page
chr:      .res 2
dst:      .res 3                ; long pointer into shrchars
mptr:     .res 3                ; long pointer into the shown matrix
scr:      .res 2
idx:      .res 2
anydirty: .res 2                ; nonzero if any character changed this call
shown_w:  .res 2                ; the window the screen shows ($ffff: nothing yet)
shown_cam: .res 2
cw:       .res 2                ; the window the logic wants
cc:       .res 2
force:    .res 2                ; nonzero: redraw every cell
ci:       .res 2                ; the cell being looked at
code:     .res 2                ; its character
ln:       .res 2                ; screen line (scrolling)
dline:    .res 2                ; its address in the screen
edge:     .res 2
t1:       .res 2
t2:       .res 2
nlist:    .res 2                ; cells in splist (those the sprites covered last time)
changed:  .res 2                ; the sprite registers differ from spstate
drawn:    .res 2                ; cells drawn or the screen shifted this call
en:       .res 2                ; p_en
msb:      .res 2                ; p_msb
tfine:    .res 2                ; t_xs
spmode:   .res 2                ; the sprite loop: 0 note the cells they cover, 1 draw their pixels
uofs:     .res 2                ; bytes in ulist (the cells to compose this call)
ui:       .res 2
ucell:    .res 2
stamp:    .res 2                ; this call's mark in cellmark
shiftdc:  .res 2                ; the screen was shifted by one cell: where a cell's picture went (-1, +1, -40, +40), else 0
scanx:    .res 2
eofs:     .res 2                ; the next 4 bytes of edgebuf
spdirty:  .res 2                ; a cell the sprites covered was redrawn (without them) this call
sk:       .res 2                ; the sprite being drawn (7 down to 0)
sx:       .res 2                ; its left edge on the screen (signed)
sy:       .res 2                ; its top line (signed)
simg:     .res 3                ; long pointer to its image
sline:    .res 2
sbyte:    .res 2
sidx:     .res 2
scol:     .res 2                ; screen byte column of the sprite's pixel 0 (signed)
dbase:    .res 2                ; address of the current screen line
pcol:     .res 2
tmpv:     .res 2
c0:       .res 2
c1:       .res 2
r0:       .res 2
r1:       .res 2

.macro shr_enter
        clc
        xce                     ; native mode
        rep     #$30
        .a16
        .i16
        phb
        phd
        pea     HALDP
        pld
.endmacro

.macro shr_exit
        pld
        plb
        sep     #$30
        sec
        xce                     ; back to the logic's mode
        rtl
.endmacro

.macro zero_table sym, bytes
        ldx     #0
        lda     #0
:       sta     f:sym,x
        inx
        inx
        cpx     #bytes
        bne     :-
.endmacro

; the byte at a logic address into A (16-bit, high byte zero)
.macro read8 addr
        sep     #$20
        lda     f:LOGIC + addr
        rep     #$20
        and     #$00ff
.endmacro

; the screen is kept in bank 1 ($2000-$9CFF, fast RAM); with the shadow register's bit 3 clear every write there is made in
; bank $E1 as well (Apple IIgs Technical Note #70). Reads never touch the slow memory.
.macro set_bank_e1
        pea     $0101
        plb
        plb
.endmacro

; 8 lines x 4 bytes of the cell at shrchars + X to the screen at SCREEN + Y (data bank $E1)
.macro blit_cell
.repeat 8, line
        lda     f:shrchars + line * 4,x
        sta     SCREEN + line * LINE,y
        lda     f:shrchars + line * 4 + 2,x
        sta     SCREEN + line * LINE + 2,y
.endrepeat
.endmacro

; fast_scan: compare the 1000 cells of the matrix at `mat` with shadowmat, a word (two cells) at a time, four words a round
.macro fast_scan mat, lbl
        ldx     #0
lbl:
.repeat 4, k
        lda     f:LOGIC + mat + k * 2,x
        cmp     f:shadowmat + k * 2,x
        beq     :+
        stx     scanx
        txa
        clc
        adc     #k * 2
        sta     ci
        jsr     try_pair
        ldx     scanx
:
.endrepeat
        txa
        clc
        adc     #8
        tax
        cmp     #CELLS
        bcs     :+
        jmp     lbl
:
.endmacro

; the cell at shrchars + X into the compose canvas at Y (data bank = the canvas's)
.macro blit_to_canvas
.repeat 8, line
        lda     f:shrchars + line * 4,x
        sta     .loword(shrbuf) + line * LINE,y
        lda     f:shrchars + line * 4 + 2,x
        sta     .loword(shrbuf) + line * LINE + 2,y
.endrepeat
.endmacro

; the canvas cell at X to the screen at X (data bank $E1)
.macro blit_from_canvas
.repeat 8, line
        lda     f:shrbuf + line * LINE,x
        sta     SCREEN + line * LINE,x
        lda     f:shrbuf + line * LINE + 2,x
        sta     SCREEN + line * LINE + 2,x
.endrepeat
.endmacro

.macro set_bank_of sym
        pea     $0000 | (^sym << 8) | ^sym
        plb
        plb
.endmacro

.segment "CODE"

; ---- once: tables and state --------------------------------------------------------------------------------
shr_init:
        shr_enter
        ; shadow the screen: writes to bank 1 $2000-$9FFF are made in bank $E1 too (bit 3 of $C035 clear); no RAMRD / RAMWRT
        sep     #$20
        lda     f:$e0c035
        and     #$f7
        sta     f:$e0c035
        sta     f:$e0c002
        sta     f:$e0c004
        rep     #$20
        zero_table shrchars, 8192
        zero_table shadow, 2048
        zero_table dirty, 256
        zero_table shadowmat, 1000
        zero_table splist, 512
        zero_table spstate, 32
        zero_table cellmark, CELLS
        zero_table incell, CELLS
        stz     stamp
        ; the logic may have made characters before this (the display test does): all are converted by the first present
        sep     #$20
        lda     #1
        sta     f:chdirty
        ldx     #0
:       sta     f:dirty,x
        inx
        cpx     #256
        bne     :-
        rep     #$20
        stz     nlist
        lda     #$ffff
        sta     shown_w
        sta     shown_cam
        stz     anydirty
        ; cellscr[i] = the screen offset of cell i (row * 1280 + column * 4), for the 1000 cells
        ldx     #0
        stz     scr
        stz     t1              ; column
make_scr:
        lda     scr
        sta     f:cellscr,x
        clc
        adc     #4
        sta     scr
        inc     t1
        lda     t1
        cmp     #40
        bne     same_row
        stz     t1
        lda     scr
        clc
        adc     #8 * LINE - 40 * 4
        sta     scr
same_row:
        inx
        inx
        cpx     #CELLS * 2
        bne     make_scr
        shr_exit

; shr_present: the staged picture: the matrix and the sprite registers (latched: 26 bytes p_sx .. p_en, which the C64's interrupt
; passes on to the VIC-II only when `ready` is set). shr_present_hold: the matrix only, the sprites as last latched.
shr_present:
        shr_enter
        ldx     #0
latch:  lda     f:LOGIC + L_p_sx,x
        sta     f:splatch,x
        inx
        inx
        cpx     #26
        bne     latch
        bra     present_common
shr_present_hold:
        shr_enter
present_common:
        set_bank_e1
        stz     drawn
        stz     shiftdc
        stz     spdirty
        ; ---- sprites: have the registers changed since last time? (the sprites themselves are composed last, in one go)
        jsr     sprites_changed
        ; ---- which characters changed: the logic's set_char and intern call shr_char_hook for each one they write
        sep     #$20
        lda     f:chdirty
        rep     #$20
        and     #$00ff
        sta     anydirty
        sep     #$20
        lda     #0
        sta     f:chdirty
        rep     #$20
scanned:
        ; ---- reconvert them (the dirty flags stay set until the cells using them are drawn)
        lda     anydirty
        beq     converted
        stz     idx
convert_loop:
        ldx     idx
        sep     #$20
        lda     f:dirty,x
        rep     #$20
        and     #$00ff
        beq     convert_next
        lda     idx
        jsr     convert_char
convert_next:
        inc     idx
        lda     idx
        cmp     #256
        bne     convert_loop
converted:
        ; ---- the shown matrix
        read8   L_cur_buf
        beq     matrix_a
        lda     #L_MAT_B
        bra     got_matrix
matrix_a:
        lda     #L_MAT_A
got_matrix:
        sta     mptr
        sep     #$20
        lda     #^LOGIC
        sta     mptr + 2
        rep     #$20
        ; ---- has the window moved?
        read8   L_cur_w
        sta     cw
        read8   L_cur_cam
        sta     cc
        stz     force
        lda     shown_w
        cmp     #$ffff
        beq     full
        lda     cw
        sec
        sbc     shown_w
        sta     t1              ; the change in the window's column
        lda     cc
        sec
        sbc     shown_cam
        sta     t2              ; and row
        ora     t1
        beq     moved           ; no change
        lda     t2
        bne     not_horizontal
        lda     t1
        cmp     #1
        bne     :+
        jsr     shift_left      ; the window moved right: the picture moves left
        bra     moved
:       cmp     #$ffff
        bne     full
        jsr     shift_right
        bra     moved
not_horizontal:
        lda     t1
        bne     full
        lda     t2
        cmp     #1
        bne     :+
        jsr     shift_up
        bra     moved
:       cmp     #$ffff
        bne     full
        jsr     shift_down
        bra     moved
full:   lda     #1
        sta     force
        inc     drawn
moved:  lda     t1
        ora     t2
        beq     :+
        inc     drawn           ; the screen was shifted or redrawn
:       lda     cw
        sta     shown_w
        lda     cc
        sta     shown_cam
        ; ---- draw the cells that differ from what is on screen
        lda     force
        beq     :+
        jmp     slow_pass
:       lda     anydirty
        beq     :+
        jmp     dirty_pass
:       ; nothing forced and no character changed: compare the matrix with the shadow, eight cells at a time
        read8   L_cur_buf
        beq     :+
        jmp     fast_b0
:       jmp     fast_a
fast_b0:
        fast_scan L_MAT_B, fast_b
        jmp     passed
fast_a: fast_scan L_MAT_A, fast_a2
        jmp     passed
dirty_pass:                     ; some characters changed: two cells at a time, also looking up their dirty flags
        stz     ci
dp:     ldx     ci
        txy
        lda     [mptr],y
        sta     t1
        cmp     f:shadowmat,x
        bne     dp_try
        and     #$00ff
        tax
        sep     #$20
        lda     f:dirty,x
        rep     #$20
        and     #$00ff
        bne     dp_try
        lda     t1
        xba
        and     #$00ff
        tax
        sep     #$20
        lda     f:dirty,x
        rep     #$20
        and     #$00ff
        beq     dp_next
dp_try: jsr     try_cell
        inc     ci
        jsr     try_cell
        dec     ci
dp_next:
        inc     ci
        inc     ci
        lda     ci
        cmp     #CELLS
        bne     dp
        bra     passed
slow_pass:                      ; everything forced
        stz     ci
slow:   jsr     try_cell
        inc     ci
        lda     ci
        cmp     #CELLS
        bne     slow
passed: lda     anydirty
        beq     sprites
        zero_table dirty, 256
sprites:
        lda     changed
        ora     spdirty
        bne     compose_now
        lda     shiftdc
        beq     all_done
        lda     nlist
        beq     all_done        ; the screen shifted but no sprite pixels were on it
compose_now:
        jsr     compose
        lda     changed
        beq     all_done
        jsr     save_sprite_state
all_done:
        shr_exit

try_pair:
        .a16
        .i16
        jsr     try_cell
        inc     ci
        jsr     try_cell
        rts

; ---- cell ci: draw it if it differs from the shadow, or everything is forced, or its character changed
try_cell:
        .a16
        .i16
        ldy     ci
        sep     #$20
        lda     [mptr],y
        rep     #$20
        and     #$00ff
        sta     code
        ldx     ci
        sep     #$20
        cmp     f:shadowmat,x
        rep     #$20
        bne     draw_it
        lda     force
        bne     draw_it
        lda     anydirty
        beq     no_draw
        ldx     code
        sep     #$20
        lda     f:dirty,x
        rep     #$20
        and     #$00ff
        bne     draw_it
no_draw:
        rts
draw_it:
        inc     drawn
        ldx     ci
        sep     #$20
        lda     f:incell,x
        beq     :+
        inc     spdirty         ; a sprite was on this cell: it is composed again at the end
:       rep     #$20
        ldx     ci
        sep     #$20
        lda     code
        sta     f:shadowmat,x
        rep     #$20
draw_code:
        ldx     ci
        txa
        asl     a
        tax
        lda     f:cellscr,x
        sta     scr
        lda     code
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a               ; * 32 bytes a cell
        tax
        ldy     scr
        blit_cell
        rts

; ---- the window moved by one cell: shift the screen, and the shadow with it
; Horizontal: line by line, each line shifted by 4 bytes with a block move and its 4 edge bytes written at once, so the
; exposed column never shows wrapped-around bytes. The shadow's edge cells are set to what was drawn there.
shift_left:
        .a16
        .i16
        lda     #$ffff
        sta     shiftdc
        lda     #39
        jsr     build_edge
        stz     ln
        stz     eofs
        lda     #SCREEN
        sta     dline
sl_line:
        lda     dline
        tax                     ; the line's bytes 4 .. 159 to bytes 0 .. 155
        jsr     shl_line
        lda     dline
        clc
        adc     #LINE - 4
        sta     edge            ; where the new cell's 4 bytes go: the line's byte 156
        jsr     edge_put
        lda     dline
        clc
        adc     #LINE
        sta     dline
        inc     ln
        lda     ln
        cmp     #200
        bne     sl_line
        ; the shadow: every cell one place left, then the new column from the matrix
        ldx     #.loword(shadowmat) + 1
        ldy     #.loword(shadowmat)
        lda     #CELLS - 1 - 1
        mvn     shadowmat,shadowmat
        set_bank_e1             ; (a block move leaves the data bank at its destination's)
        lda     #39
        jmp     copy_column

shift_right:
        .a16
        .i16
        lda     #1
        sta     shiftdc
        lda     #0
        jsr     build_edge
        jsl     slam_right              ; (in bank 3: the stack goes on the screen)
        ldx     #.loword(shadowmat) + CELLS - 2
        ldy     #.loword(shadowmat) + CELLS - 1
        lda     #CELLS - 1 - 1
        mvp     shadowmat,shadowmat
        set_bank_e1
        lda     #0
        jmp     copy_column

; Vertical: the whole screen moves a cell row, and the new row is left for the cell pass (its shadow is made unequal).
shift_up:
        .a16
        .i16
        lda     #$ffd8
        sta     shiftdc
        stz     ln
        lda     #SCREEN
        sta     dline
su_line:
        lda     dline
        tax
        jsr     shu_line
        lda     dline
        clc
        adc     #LINE
        sta     dline
        inc     ln
        lda     ln
        cmp     #200 - 8
        bne     su_line
        ldx     #.loword(shadowmat) + 40
        ldy     #.loword(shadowmat)
        lda     #CELLS - 40 - 1
        mvn     shadowmat,shadowmat
        set_bank_e1             ; (a block move leaves the data bank at its destination's)
        lda     #24 * 40
        jmp     unsettle_row

shift_down:
        .a16
        .i16
        lda     #40
        sta     shiftdc
        jsl     slam_down
        ldx     #.loword(shadowmat) + CELLS - 40 - 1
        ldy     #.loword(shadowmat) + CELLS - 1
        lda     #CELLS - 40 - 1
        mvp     shadowmat,shadowmat
        set_bank_e1
        lda     #0
        jmp     unsettle_row

; the line at X (its address in bank $E1) shifted 4 bytes left / right: 78 words each, 16-bit loads and stores
shl_line:
        .a16
        .i16
.repeat 78, k
        lda     a:4 + k * 2,x
        sta     a:k * 2,x
.endrepeat
        rts

shr_line:
        .a16
        .i16
.repeat 78, j
        lda     a:2 * (77 - j),x
        sta     a:4 + 2 * (77 - j),x
.endrepeat
        rts

; one line moved up / down by a cell row (8 lines): the line at X (its address in bank $E1): 80 words
shu_line:                               ; from the line 8 below
        .a16
        .i16
.repeat 80, k
        lda     a:8 * LINE + k * 2,x
        sta     a:k * 2,x
.endrepeat
        rts

shd_line:                               ; to the line 8 below
        .a16
        .i16
.repeat 80, k
        lda     a:k * 2,x
        sta     a:8 * LINE + k * 2,x
.endrepeat
        rts

; build_edge: the 25 cells of matrix column A (0 or 39) as 25 x 32 bytes in edgebuf: screen line n of the column is at n * 4
build_edge:
        .a16
        .i16
        sta     t1                      ; the cell index, row by row
        stz     idx                     ; the row
        lda     #.loword(edgebuf)
        sta     dst
        sep     #$20
        lda     #.bankbyte(edgebuf)
        sta     dst + 2
        rep     #$20
be_row: ldy     t1
        sep     #$20
        lda     [mptr],y
        rep     #$20
        and     #$00ff
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a                       ; * 32 bytes a cell
        tax
        lda     idx
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a                       ; row * 32
        tay
.repeat 16, w
        lda     f:shrchars + w * 2,x
        sta     [dst],y
.if w < 15
        iny
        iny
.endif
.endrepeat
        lda     t1
        clc
        adc     #40
        sta     t1
        inc     idx
        lda     idx
        cmp     #25
        beq     :+
        jmp     be_row
:       rts

; edge_put: the next 4 bytes of edgebuf to `edge` (data bank $E1)
edge_put:
        .a16
        .i16
        ldy     edge
        ldx     eofs
        lda     f:edgebuf,x
        sta     a:$0000,y
        lda     f:edgebuf + 2,x
        sta     a:$0002,y
        txa
        clc
        adc     #4
        sta     eofs
        rts

; edge_cell_bytes: screen line `ln`'s 4 bytes of the cell in column A (0 or 39) of the matrix, to `edge` (data bank $E1)
edge_cell_bytes:
        .a16
        .i16
        sta     t1              ; the column
        lda     ln
        lsr     a
        lsr     a
        lsr     a               ; the matrix row
        sta     t2
        asl     a
        asl     a
        asl     a               ; row * 8
        sta     idx
        lda     t2
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a               ; row * 32
        clc
        adc     idx             ; row * 40
        clc
        adc     t1
        tay
        sep     #$20
        lda     [mptr],y        ; the character
        rep     #$20
        and     #$00ff
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a               ; * 32 bytes a cell
        sta     t1
        lda     ln
        and     #7
        asl     a
        asl     a               ; * 4 bytes a line of the cell
        clc
        adc     t1
        tax
        ldy     edge
        lda     f:shrchars,x
        sta     a:$0000,y
        lda     f:shrchars + 2,x
        sta     a:$0002,y
        rts

; copy_column: shadow column A (0 or 39) of every row := the matrix's
copy_column:
        .a16
        .i16
        sta     t1
        ldx     t1              ; the cell index, row by row
        ldy     t1
        lda     #25
        sta     t2
cc_row: sep     #$20
        lda     [mptr],y
        sta     f:shadowmat,x
        rep     #$20
        txa
        clc
        adc     #40
        tax
        tay
        dec     t2
        bne     cc_row
        rts

; unsettle_row: shadow row starting at cell A (0 or 960) := the matrix's xor $ff, so the cell pass draws it
unsettle_row:
        .a16
        .i16
        tax
        tay
        lda     #40
        sta     t2
ur:     sep     #$20
        lda     [mptr],y
        eor     #$ff
        sta     f:shadowmat,x
        rep     #$20
        inx
        iny
        dec     t2
        bne     ur
        rts


; ---- sprites ----------------------------------------------------------------------------------------------

; sprites_changed: changed := the 26 bytes p_sx .. p_en or t_xs differ from the copy in spstate
sprites_changed:
        .a16
        .i16
        stz     changed
        ldx     #0
sc_loop:
        lda     f:splatch,x
        cmp     f:spstate,x
        bne     sc_diff
        inx
        inx
        cpx     #26
        bne     sc_loop
        read8   L_t_xs
        cmp     f:spstate + 26
        beq     sc_done
sc_diff:
        lda     #1
        sta     changed
sc_done:
        rts

save_sprite_state:
        .a16
        .i16
        ldx     #0
ss_loop:
        lda     f:splatch,x
        sta     f:spstate,x
        inx
        inx
        cpx     #26
        bne     ss_loop
        read8   L_t_xs
        sta     f:spstate + 26
        rts

; compose: the cells the sprites covered (and, if the screen was shifted, where their pixels went) and the cells they cover now are
; each built off-screen, the background with the sprites over it, and written to the screen once: a sprite never disappears
; between being erased and being drawn. (The canvas `shrbuf` has the screen's layout; only the cells being composed are valid.)
compose:
        .a16
        .i16
        inc     stamp
        lda     stamp
        and     #$00ff
        bne     cm_stamped
        zero_table cellmark, CELLS
        lda     #1
        sta     stamp
cm_stamped:
        stz     uofs
        ; the old cells (and where a shift took their pixels) go in the list; they are no longer covered by a sprite
        stz     idx
cm_old: lda     idx
        cmp     nlist
        bcc     :+
        jmp     cm_old_done
:       asl     a
        tax
        lda     f:splist,x
        sta     ucell
        tax
        sep     #$20
        lda     #0
        sta     f:incell,x
        rep     #$20
        lda     ucell
        pha
        jsr     add_u
        pla
        ldx     shiftdc
        beq     cm_next
        clc
        adc     shiftdc
        bmi     cm_next
        cmp     #CELLS
        bcs     cm_next
        jsr     add_u
cm_next:
        inc     idx
        bra     cm_old
cm_old_done:
        stz     nlist
        ; the cells they cover now
        stz     spmode
        jsr     sprite_loop
        ; 1. the background of every cell in the canvas
        set_bank_of shrbuf
        stz     ui
cm_bg:  lda     ui
        cmp     uofs
        bcc     :+
        jmp     cm_bg_done
:
        tax
        lda     f:ulist,x
        sta     ucell
        tax
        sep     #$20
        lda     f:shadowmat,x
        rep     #$20
        and     #$00ff
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a               ; * 32 bytes a cell
        sta     t1
        lda     ucell
        asl     a
        tax
        lda     f:cellscr,x
        tay
        ldx     t1
        blit_to_canvas
        inc     ui
        inc     ui
        jmp     cm_bg
cm_bg_done:
        ; 2. the sprites over it
        lda     #1
        sta     spmode
        jsr     sprite_loop
        ; 3. the screen: each cell once
        set_bank_e1
        stz     ui
cm_out: lda     ui
        cmp     uofs
        bcc     :+
        rts
:
        tax
        lda     f:ulist,x
        asl     a
        tax
        lda     f:cellscr,x
        tax
        blit_from_canvas
        inc     ui
        inc     ui
        jmp     cm_out

; add_u: cell A to ulist unless it is there already this call
add_u:
        .a16
        .i16
        sta     ucell
        tax
        sep     #$20
        lda     f:cellmark,x
        cmp     stamp
        beq     au_have
        lda     stamp
        sta     f:cellmark,x
        rep     #$20
        ldx     uofs
        lda     ucell
        sta     f:ulist,x
        inx
        inx
        stx     uofs
        rts
au_have:
        rep     #$20
        rts

; sprite_loop: every enabled sprite, 7 down to 0 so that sprite 0 ends on top. spmode 0: note the cells each covers (nlist, splist,
; incell, and the list to compose); spmode 1: draw its pixels into the canvas (data bank = the canvas's)
sprite_loop:
        .a16
        .i16
        lda     f:splatch + 25
        and     #$00ff
        sta     en
        lda     f:splatch + 24
        and     #$00ff
        sta     msb
        read8   L_t_xs
        sta     tfine
        lda     #7
        sta     sk
sp_next:
        ldx     sk
        lda     f:sprite_bits,x
        and     #$00ff
        and     en
        bne     :+
        jmp     sp_skip
:       ; x: 9 bits, then to screen coordinates
        sep     #$20
        lda     f:splatch,x
        rep     #$20
        and     #$00ff
        sta     sx
        lda     f:sprite_bits,x
        and     #$00ff
        and     msb
        beq     :+
        lda     sx
        ora     #$0100
        sta     sx
:       lda     sx
        sec
        sbc     #24
        sec
        sbc     tfine
        sta     sx
        sep     #$20
        lda     f:splatch + 8,x
        rep     #$20
        and     #$00ff
        sec
        sbc     #50
        sta     sy
        ; on screen at all? x in -24 .. 319, y in -21 .. 199
        lda     sx
        clc
        adc     #24
        cmp     #344
        bcc     :+
        jmp     sp_skip
:       lda     sy
        clc
        adc     #21
        cmp     #221
        bcc     :+
        jmp     sp_skip
:       lda     spmode
        beq     sp_note
        ; the image: SPRAREA + p_ptr * 64
        sep     #$20
        lda     f:splatch + 16,x
        rep     #$20
        and     #$00ff
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a
        clc
        adc     #L_SPRAREA
        sta     simg
        sep     #$20
        lda     #^LOGIC
        sta     simg + 2
        rep     #$20
        jsr     draw_sprite_pixels
        bra     sp_skip
sp_note:
        jsr     note_cells
sp_skip:
        dec     sk
        bmi     :+
        jmp     sp_next
:       rts

sprite_bits:
        .byte   $01, $02, $04, $08, $10, $20, $40, $80
; the pixel byte for a two-bit value, indexed by value * 2 (the value in the byte's both nibbles)
pixtab: .word   $00, $11, $22, $33

; note_cells: add the cells the sprite (sx, sy, 24 x 21) touches to splist, clipped to the screen
note_cells:
        .a16
        .i16
        lda     sx
        jsr     div8_floor
        bpl     :+
        lda     #0
:       sta     c0
        lda     sx
        clc
        adc     #23
        jsr     div8_floor
        cmp     #40
        bcc     :+
        lda     #39
:       sta     c1
        lda     sy
        jsr     div8_floor
        bpl     :+
        lda     #0
:       sta     r0
        lda     sy
        clc
        adc     #20
        jsr     div8_floor
        cmp     #25
        bcc     :+
        lda     #24
:       sta     r1
nc_row:
        lda     r0
        asl     a
        asl     a
        asl     a
        sta     t1              ; row * 8
        lda     r0
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a               ; row * 32
        clc
        adc     t1              ; row * 40
        clc
        adc     c0
        sta     t1              ; the first cell of this row's span
        lda     c0
        sta     pcol
nc_col:
        lda     nlist
        cmp     #256
        bcs     nc_full         ; no room: the list is full (cannot happen with 8 sprites of at most 16 cells ... but be safe)
        asl     a
        tax
        lda     t1
        sta     f:splist,x
        inc     nlist
        ldx     t1
        sep     #$20
        lda     #1
        sta     f:incell,x
        rep     #$20
        lda     t1
        pha
        jsr     add_u
        pla
        sta     t1
nc_full:
        inc     t1
        inc     pcol
        lda     pcol
        cmp     c1
        bcc     nc_col
        beq     nc_col
        inc     r0
        lda     r0
        cmp     r1
        bcc     nc_row
        beq     nc_row
        rts

; div8_floor: A (signed) / 8, rounded down
div8_floor:
        .a16
        .i16
        cmp     #$8000
        ror     a
        cmp     #$8000
        ror     a
        cmp     #$8000
        ror     a
        rts

; draw_sprite_pixels: the sprite's 21 lines of 12 pixels, each non-zero pixel one byte on the screen (data bank $E1)
draw_sprite_pixels:
        .a16
        .i16
        lda     sx
        cmp     #$8000
        ror     a               ; sx / 2: the screen byte column of pixel 0 (sx is even)
        sta     scol
        stz     sline
dl_line:
        lda     sy
        clc
        adc     sline
        cmp     #200
        bcc     :+
        jmp     dl_next_line    ; above or below the screen
:
        sta     t1
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a               ; line * 32
        sta     t2
        lda     t1
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a               ; line * 128
        clc
        adc     t2              ; line * 160
        clc
        adc     #.loword(shrbuf)
        sta     dbase
        lda     sline
        asl     a
        clc
        adc     sline           ; line * 3: the offset of this line's 3 image bytes
        tay
        stz     sidx
dl_byte:
        sep     #$20
        lda     [simg],y
        rep     #$20
        and     #$00ff
        bne     :+
        jmp     dl_byte_next    ; four transparent pixels
:
        sta     sbyte
        lda     sidx
        asl     a
        asl     a               ; the first of this byte's four pixels, in pixels
        clc
        adc     scol
        sta     pcol            ; its screen byte column
        sty     idx             ; (Y holds the image offset: keep it)
.repeat 4
        lda     sbyte
        and     #$00c0
        beq     :+
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        lsr     a               ; value * 2
        tax
        lda     f:pixtab,x
        sta     tmpv
        lda     pcol
        cmp     #160
        bcs     :+              ; off the screen to the left or right
        clc
        adc     dbase
        tax
        sep     #$20
        lda     tmpv
        sta     a:$0000,x
        rep     #$20
:       asl     sbyte
        asl     sbyte
        inc     pcol
.endrepeat
        ldy     idx
dl_byte_next:
        iny
        inc     sidx
        lda     sidx
        cmp     #3
        beq     dl_next_line
        jmp     dl_byte
dl_next_line:
        inc     sline
        lda     sline
        cmp     #21
        beq     dl_done
        jmp     dl_line
dl_done:
        rts

; the word offset in X (characters X and X + 1) changed
; shr_char_hook: JSL'd (by the logic's hal_store_char, through the platform's entry table) with Y = the character, emulation mode,
; 8-bit registers, after the logic stored its 8 BBC bytes in BPAT. A character whose bytes differ from the shadow copy is flagged
; for conversion.
.a8
.i8
shr_char_hook:
        phx
        tyx
.repeat 8, n
        lda     f:LOGIC + L_BPAT + n * 256,x
        cmp     f:shadow + n * 256,x
        beq     :+
        sta     f:shadow + n * 256,x
        lda     #1
        sta     f:dirty,x
        sta     f:chdirty
:
.endrepeat
        plx
        rtl
.a16
.i16

mark_pair:
        .a16
        .i16
        sep     #$20
        lda     #1
        sta     f:dirty,x
        sta     f:dirty + 1,x
        rep     #$20
        inc     anydirty
        rts

; the BBC bytes of character A (BPAT) into its 32 bytes in shrchars
convert_char:
        .a16
        .i16
        sta     chr
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a
        clc
        adc     #.loword(shrchars)
        sta     dst
        sep     #$20
        lda     #.bankbyte(shrchars)
        sta     dst + 2
        rep     #$20
.repeat 8, line
        ldx     chr
        sep     #$20
        lda     f:LOGIC + L_BPAT + line * 256,x
        sta     f:shadow + line * 256,x    ; (what the hook compares against)
        rep     #$20
        and     #$00ff
        asl     a
        asl     a               ; * 4 bytes a BBC byte
        tax
        lda     f:bbc2shr,x
        ldy     #line * 4
        sta     [dst],y
        lda     f:bbc2shr + 2,x
        ldy     #line * 4 + 2
        sta     [dst],y
.endrepeat
        rts

; ---- the stack slam ---------------------------------------------------------------------------------------------------------
; Apple IIgs Technical Note #70 and the PEI slammers of the IIgs game engines: with RAMWRT ($C005) set, the stack (and any other
; write to bank 0 $0200-$BFFF) is in bank 1, and with bit 3 of the shadow register clear every write to bank 1 $2000-$9FFF is
; also made in bank $E1. With RAMRD ($C003) set too, PEI reads bank 1 as well. So `PEI` (push the word at D + n) moves two
; bytes of the picture, in bank 1, to the stack, which is the picture: 6 cycles (7 when the low byte of D is not 0) for two
; bytes, against 12 for a load and a store. Pushes go downwards, so it can only move data to higher addresses in place.
; While it runs: interrupts off, S and D are saved and restored, and the code is outside bank 0 (instruction fetches from bank 0
; $0200-$BFFF would be read from bank 1), and nothing may call the firmware (TN #70).
.segment "SLAM"
.a16
.i16

.macro slam_enter
        php
        sei
        tsc
        sta     f:slam_save
        tdc
        sta     f:slam_save + 2
        sep     #$20
        sta     f:$e0c005               ; RAMWRT on
        sta     f:$e0c003               ; RAMRD on
        rep     #$20
.endmacro

.macro slam_leave
        sep     #$20
        sta     f:$e0c004               ; RAMWRT off
        sta     f:$e0c002               ; RAMRD off
        rep     #$20
        lda     f:slam_save + 2
        tcd
        lda     f:slam_save
        tcs
        plp
        rtl
.endmacro

; slam_right: every screen line 4 bytes to the right (bytes 0 - 155 to 4 - 159), its 4 new bytes at the left from edgebuf
slam_right:
        slam_enter
        ldy     #SCREEN                 ; the line's address
        ldx     #0                      ; the next 4 bytes of edgebuf
sr_next:
        tya
        tcd                             ; D = the line (the words are read at D + n)
        clc
        adc     #LINE - 1
        tcs                             ; S = its last byte
.repeat 78, k
        .byte   $d4, 2 * (77 - k)       ; pei (2 * (77 - k)): word 77 - k to word 79 - k (ca65 will not take the expression)
.endrepeat
        lda     f:edgebuf + 2,x
        pha                             ; bytes 2 and 3
        lda     f:edgebuf,x
        pha                             ; bytes 0 and 1
        inx
        inx
        inx
        inx
        tya
        clc
        adc     #LINE
        tay
        cpy     #SCREEN + 200 * LINE
        beq     sr_done
        jmp     sr_next
sr_done:
        slam_leave

; slam_down: every screen line 8 lines (a cell row) lower, the bottom lines first (lines 0 - 191 to 8 - 199)
slam_down:
        slam_enter
        ldy     #SCREEN + 191 * LINE    ; the source line
sd_next:
        tya
        tcd                             ; D = the source line
        clc
        adc     #8 * LINE + LINE - 1
        tcs                             ; S = the last byte of the line 8 lower
.repeat 80, k
        .byte   $d4, 2 * (79 - k)       ; pei (2 * (79 - k))
.endrepeat
        tya
        sec
        sbc     #LINE
        tay
        cpy     #SCREEN - LINE
        beq     sd_done
        jmp     sd_next
sd_done:
        slam_leave
