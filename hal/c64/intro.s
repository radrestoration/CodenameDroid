; intro.s: the loading screens of the BBC disc (its BASIC front end, CDroid), before the game starts.
;
;   0  the instruction pages of the BBC's tape inlay (MODE 7 there), in the C64's own text mode and character set:
;      SPACE (or fire) for the next, RUN/STOP to skip them
;   1  the logo (picture 1)         8 seconds, or any key
;   2  a full screen picture        8 seconds, or any key
;   3  PRESENTING, the logo strip and the credits: SPACE (or fire) starts the game, V shows the controls
;   4  the controls, then the wrist terminal's: SPACE for the next, and back to 3
; The pictures are multicolour bitmaps and the text a character screen (tools/make_intro.py makes the data). It all
; lives in VIC-II bank 3 ($c000-$ffff): the bitmap or the character set at $e000, the screen RAM at $cc00, so nothing
; of the game's own memory is touched except what start-up fills in afterwards (the cell tables, the sound driver).
; Without the disc to make them from (INTRO_PRESENT = 0) there is nothing to show.

.include "intro_data.s"

.segment "INTRO"                  ; (the code too: it only runs before the game's own memory is set up)

.if INTRO_PRESENT

INTRO_SKIP   = $0278            ; $a5 here (a test sets it) skips the loading screens
INTRO_PAGE   = $0279            ; the instruction page being shown
INTRO_FLAGS  = $027a            ; intro_textpage: bit 0 = the logo strip, bit 1 = the C64's lower case character set
INTRO_TBL    = $027b            ; (2) the table of texts
INTRO_PAGEBUF = $f000           ; an unpacked instruction page
INTRO_STRIPBUF = $f400          ; the unpacked logo strip
INTRO_T      = $027d            ; the scroll: time in steps,
INTRO_ACC    = $027e            ; the accumulator that makes a step every 3 PAL frames (3.6 NTSC),
INTRO_POS    = $027f            ; the picture line at the top of the screen (0-64),
INTRO_CUR    = $028a            ; the buffer on show (0 = bank 3, 1 = bank 1),
INTRO_SEG    = $028b            ; the cell row the other one is being made for,
INTRO_ROW    = $028c            ; the cell rows of it done,
INTRO_RATE   = $028d
INTRO_SRC    = $028e            ; (2) where the next row of it comes from,
INTRO_DST    = $0290            ; (2) and goes,
INTRO_XSRC   = $0292            ; (2) the next of the picture's extra rows
INTRO_Y_BITMAP = $6000          ; the second buffer: bank 1, its screen RAM at $5c00
INTRO_Y_SCREEN = $5c00
INTRO_HOLD   = $d400            ; the extra rows (RAM under the I/O area)
INTRO_SCREEN = $d000            ; (RAM under the VIC-II's registers: the CPU gets at it with $01 = $34; the colour RAM is at $d800)
INTRO_BITMAP = $e000
INTRO_COLOUR = $d800
IRED   = 2
IWHITE = 1
IGREEN = 5

intro_run:
    lda INTRO_SKIP
    cmp #$a5
    bne @go
    rts
@go:
    lda #0
    sta $d011                   ; the screen off while it is set up
    ldx #$1c                    ; the key variables ($0230-$024c) and the scan's copy of the matrix
    lda #0
@k: sta kb_rows,x
    dex
    bpl @k
    ldx #8
@kp:
    sta kb_prev,x
    dex
    bpl @kp
    jsr c64_scan_keys           ; (a key that is down already, from starting the game, is not a key press)
    lda #0
    sta kb_ascii
    lda $dd02
    ora #3
    sta $dd02
    lda $dd00
    and #$fc                    ; VIC-II bank 3
    sta $dd00
    lda #0
    sta $d020
    sta $d021

    lda #0
    sta INTRO_PAGE
@m7:
    ldx INTRO_PAGE
    cpx #INTRO_M7_PAGES
    beq @m7done
    lda #2                      ; (the C64's lower case characters)
    jsr intro_showpage
    jsr intro_space
    bcs @m7done                 ; (RUN/STOP)
    inc INTRO_PAGE
    jmp @m7
@m7done:
    jsr intro_logo
    jsr intro_pause_split
.if INTRO_SCROLL
    jsr intro_scrollpic
.else
    lda #<intro_img2
    sta zp_p1
    lda #>intro_img2
    sta zp_p1+1
    lda #INTRO_COLOURS2
    jsr intro_picture
    jsr intro_pause
.endif

@credits:
    ldx #INTRO_PG_CREDITS
    lda #1                      ; with the logo strip
    jsr intro_showpage
@c: jsr intro_frame
    jsr intro_key
    bcc @c
    cmp #' '
    beq @start
    cmp #$0d                    ; (fire)
    beq @start
    cmp #'V'
    bne @c
    ldx #INTRO_PG_KEYS
    lda #0
    jsr intro_showpage
    jsr intro_space
    ldx #INTRO_PG_TERMINAL
    lda #0
    jsr intro_showpage
    jsr intro_space
    jmp @credits
@start:
    lda #0
    sta $d011
    ldy #100                    ; (let go of the key, so that the game does not see it)
@r: jsr intro_frame
    jsr c64_scan_keys
    lda kb_nheld
    beq @out
    dey
    bne @r
@out:
    lda #0
    sta kb_ascii
    rts

; intro_showpage: X = a page (of the packed tables intro_m7_*), A = the flags for intro_textpage: unpack it and show it
intro_showpage:
    pha
    lda intro_m7_lo,x
    sta zp_p1
    lda intro_m7_hi,x
    sta zp_p1+1
    lda #<INTRO_PAGEBUF
    sta zp_u
    clc
    adc intro_m7_sl,x
    sta zp_ci
    lda #>INTRO_PAGEBUF
    sta zp_u+1
    adc intro_m7_sh,x
    sta zp_ci+1
    jsr intro_huff
    lda #<INTRO_PAGEBUF
    sta zp_p1
    lda #>INTRO_PAGEBUF
    sta zp_p1+1
    pla
    jmp intro_textpage

; intro_huff: zp_p1 = a Huffman coded page (tools/make_intro.py: a canonical code, intro_hf_count and intro_hf_syms), zp_u = where
; to, zp_ci = where that ends
intro_huff:
    lda #0
    sta zp_v+1                  ; (no bits left in the byte)
@sym:
    lda #0
    sta zp_d                    ; the code so far
    sta zp_d+1
    sta zp_idx                  ; the first code of this length
    sta zp_idx+1
    sta zp_h                    ; the index of the first symbol of this length
    tax                         ; X = the length - 1
@bit:
    lda zp_v+1
    bne @have
    ldy #0
    lda (zp_p1),y
    sta zp_v
    inc zp_p1
    bne @b1
    inc zp_p1+1
@b1:
    lda #8
    sta zp_v+1
@have:
    asl zp_v
    rol zp_d
    rol zp_d+1
    dec zp_v+1
    lda intro_hf_count,x
    sta zp_t                    ; the codes of this length
    sec
    lda zp_d
    sbc zp_idx
    tay                         ; code - first
    lda zp_d+1
    sbc zp_idx+1
    bne @next
    cpy zp_t
    bcc @found
@next:
    lda zp_h                    ; on to the next length: the symbols and the codes so far, doubled
    clc
    adc zp_t
    sta zp_h
    lda zp_idx
    clc
    adc zp_t
    sta zp_idx
    bcc @n1
    inc zp_idx+1
@n1:
    asl zp_idx
    rol zp_idx+1
    inx
    bne @bit
@found:
    tya
    clc
    adc zp_h
    tay
    lda intro_hf_syms,y
    ldy #0
    sta (zp_u),y
    inc zp_u
    bne @u1
    inc zp_u+1
@u1:
    lda zp_u+1
    cmp zp_ci+1
    bcc @sym
    lda zp_u
    cmp zp_ci
    bcc @sym
    rts

; intro_space: wait for SPACE (or fire): C = 0; or for RUN/STOP: C = 1
intro_space:
    jsr intro_frame
    jsr intro_key
    bcc intro_space
    cmp #' '
    beq @ok
    cmp #$0d
    beq @ok
    cmp #3
    beq @stop
    bne intro_space
@ok:
    clc
    rts
@stop:
    sec
    rts

; intro_frame: one frame goes by (raster line $f8 is passed)
intro_frame:
@a: lda $d012
    cmp #$f8
    beq @a
@b: lda $d012
    cmp #$f8
    bne @b
    rts

; intro_key: C = 1 if a key was pressed since the last call (A = its ASCII)
intro_key:
    jsr c64_scan_keys
    lda kb_ascii
    beq @no
    ldx #0
    stx kb_ascii
    sec
    rts
@no:
    clc
    rts

.if !INTRO_SCROLL
; intro_pause: 8 seconds, or until a key
intro_pause:
    ldx #<400
    ldy #>400
    lda c64_pal
    bne @n
    ldx #<480
    ldy #>480
@n: stx zp_ci
    sty zp_ci+1
@l: jsr intro_frame
    jsr intro_key
    bcs @r
    lda zp_ci
    bne @d
    dec zp_ci+1
@d: dec zp_ci
    lda zp_ci
    ora zp_ci+1
    bne @l
@r: rts

.endif

; intro_logo: the logo screen: multicolour above raster line INTRO_SPLIT_LINE, hires below it (the screen RAM is the
; picture's own: two colours a cell). intro_pause_split switches the mode as the beam goes down the screen.
intro_logo:
    lda #0
    sta $d011
    lda #<intro_img1
    sta zp_p1
    lda #>intro_img1
    sta zp_p1+1
    lda #<INTRO_BITMAP
    sta zp_u
    lda #>INTRO_BITMAP
    sta zp_u+1
    lda #<(INTRO_BITMAP + 8000)
    sta zp_ci
    lda #>(INTRO_BITMAP + 8000)
    sta zp_ci+1
    jsr intro_unpack
    lda #<intro_img1s
    sta zp_p1
    lda #>intro_img1s
    sta zp_p1+1
    lda #<INTRO_SCREEN
    sta zp_u
    lda #>INTRO_SCREEN
    sta zp_u+1
    lda #<(INTRO_SCREEN + 1000)
    sta zp_ci
    lda #>(INTRO_SCREEN + 1000)
    sta zp_ci+1
    lda #$34                    ; (the screen RAM is under the I/O area)
    sta $01
    jsr intro_unpack
    lda #$35
    sta $01
    lda #IWHITE                 ; colour RAM: the multicolour part's third colour
    ldx #>INTRO_COLOUR
    jsr intro_fill_screen
    lda #$48
    sta $d018
    lda #$18
    sta $d016
    lda #$3b                    ; bitmap, on
    sta $d011
    rts

; intro_pause_split: intro_pause for the logo screen: each frame, hires from INTRO_SPLIT_LINE (in the black between the
; logo and its caption, at a cell boundary: whichever mode the first line is in, it is black) to near the bottom
intro_pause_split:
    ldx #<400
    ldy #>400
    lda c64_pal
    bne @n
    ldx #<480
    ldy #>480
@n: stx zp_ci
    sty zp_ci+1
@l: lda $d012
    cmp #INTRO_SPLIT_LINE
    bne @l
    lda #$08                    ; hires
    sta $d016
@b: lda $d012
    cmp #252
    bne @b
    lda #$18                    ; multicolour again (it is the next frame's top)
    sta $d016
    jsr intro_key               ; (in the blank lines: it takes about 27)
    bcs @r
    lda zp_ci
    bne @d
    dec zp_ci+1
@d: dec zp_ci
    lda zp_ci
    ora zp_ci+1
    bne @l
@r: rts

.if INTRO_SCROLL
; ------------------------------------------------------------------------------------------------
; The full screen picture, scrolled. It is 256 lines and the screen shows 192 (24 rows: the border hides the top and bottom
; 4 lines of the 25 rows of the bitmap, which keeps the picture filling the window whatever the fine scroll is), so it
; moves up 64 lines, one line each 3 frames (60 ms: PAL; NTSC 3.6 frames), after a pause at the top and before one at the
; bottom: 130 steps in all, about 7.8 seconds, or until a key.
; The fine scroll is the VIC-II's vertical scroll (the picture line at the top is 8 * cell row + 7 - YSCROLL); every 8 lines
; the bitmap has to move up a cell row, 7,700 bytes: it is made in the other buffer (the bitmap in bank 1 or bank 3), two
; cell rows a frame, and the VIC-II is switched to it in the blank lines at the bottom of a frame, so nothing tears.
; The other 7 cell rows of the picture wait in RAM under the I/O area. Everything happens at raster line 252, after
; the last visible one.
intro_scrollpic:
    lda #0
    sta $d011
    lda #<intro_img2            ; the first 25 cell rows: the bitmap in bank 3
    sta zp_p1
    lda #>intro_img2
    sta zp_p1+1
    lda #<INTRO_BITMAP
    sta zp_u
    lda #>INTRO_BITMAP
    sta zp_u+1
    lda #<(INTRO_BITMAP + 8000)
    sta zp_ci
    lda #>(INTRO_BITMAP + 8000)
    sta zp_ci+1
    jsr intro_unpack
    lda #<intro_img2x           ; the rest (and a blank row)
    sta zp_p1
    lda #>intro_img2x
    sta zp_p1+1
    lda #<INTRO_HOLD
    sta zp_u
    lda #>INTRO_HOLD
    sta zp_u+1
    lda #<(INTRO_HOLD + 2560)
    sta zp_ci
    lda #>(INTRO_HOLD + 2560)
    sta zp_ci+1
    lda #$34
    sta $01
    jsr intro_unpack
    lda #$35
    sta $01
    lda #INTRO_COLOURS2         ; the screen RAM of both buffers, and the colour RAM
    jsr intro_fill_ram
    lda #INTRO_COLOURS2
    ldx #>INTRO_Y_SCREEN
    jsr intro_fill_screen
    lda #IWHITE
    ldx #>INTRO_COLOUR
    jsr intro_fill_screen
    lda #0
    sta INTRO_T
    sta INTRO_ACC
    sta INTRO_POS
    sta INTRO_CUR
    sta INTRO_SEG
    sta INTRO_ROW
    lda #<INTRO_HOLD
    sta INTRO_XSRC
    lda #>INTRO_HOLD
    sta INTRO_XSRC+1
    ldx #6                      ; 6/18 a frame: a step every 3 frames (PAL); NTSC 5/18: 3.6
    lda c64_pal
    bne @r
    ldx #5
@r: stx INTRO_RATE
    jsr intro_seg_init
    lda $dd00
    and #$fc                    ; bank 3
    sta $dd00
    lda #$48                    ; screen RAM at $d000, bitmap at $e000
    sta $d018
    lda #$18
    sta $d016
    lda #$37                    ; bitmap, 24 rows, on; YSCROLL 7: the picture's line 0 at the top of the window
    sta $d011
@frame:
@w: lda $d012
    cmp #252
    bne @w
    jsr intro_scroll_step
    jsr intro_scroll_prepare
    jsr intro_key
    bcs @out
    lda INTRO_T
    cmp #130
    bcc @frame
@out:
    lda $dd00
    and #$fc                    ; back to bank 3 for the next screen
    sta $dd00
    rts

intro_scroll_step:
    lda INTRO_ACC
    clc
    adc INTRO_RATE
    cmp #18
    bcc @keep
    sbc #18
    sta INTRO_ACC
    inc INTRO_T
    lda INTRO_T                 ; the line at the top: t - 25 (a pause first), at most 64 (and one after)
    sec
    sbc #25
    bcc @done
    cmp #65
    bcc @ok
    lda #64
@ok:
    cmp INTRO_POS
    beq @done
    sta INTRO_POS
    and #7
    eor #7
    ora #$30
    sta $d011                   ; YSCROLL = 7 - (line mod 8)
    lda INTRO_POS
    and #7
    bne @done
    lda INTRO_CUR               ; the cell row has gone by: the other buffer, made ready
    eor #1
    sta INTRO_CUR
    bne @y
    lda $dd00
    and #$fc                    ; bank 3
    sta $dd00
    lda #$48
    bne @d
@y: lda $dd00
    and #$fc
    ora #2                      ; bank 1
    sta $dd00
    lda #$78                    ; screen RAM at $5c00, the bitmap at $6000
@d: sta $d018
    inc INTRO_SEG
    lda #0
    sta INTRO_ROW
    jmp intro_seg_init
@keep:
    sta INTRO_ACC
@done:
    rts

; intro_seg_init: the pointers for making the other buffer: its row 0 comes from the shown one's row 1
intro_seg_init:
    lda INTRO_CUR
    bne @y
    lda #<(INTRO_BITMAP + 320)  ; shown: bank 3
    sta INTRO_SRC
    lda #>(INTRO_BITMAP + 320)
    sta INTRO_SRC+1
    lda #<INTRO_Y_BITMAP
    sta INTRO_DST
    lda #>INTRO_Y_BITMAP
    sta INTRO_DST+1
    rts
@y: lda #<(INTRO_Y_BITMAP + 320)
    sta INTRO_SRC
    lda #>(INTRO_Y_BITMAP + 320)
    sta INTRO_SRC+1
    lda #<INTRO_BITMAP
    sta INTRO_DST
    lda #>INTRO_BITMAP
    sta INTRO_DST+1
    rts

; intro_scroll_prepare: up to 2 cell rows of the next buffer a frame (13 frames of the 24 a cell row lasts)
intro_scroll_prepare:
    lda INTRO_SEG
    cmp #8
    bcs @r
    ldx #2
@l: lda INTRO_ROW
    cmp #25
    bcs @r
    stx zp_t
    jsr intro_copy_row
    ldx zp_t
    inc INTRO_ROW
    dex
    bne @l
@r: rts

; intro_copy_row: row INTRO_ROW (of 25) of the other buffer: from the shown one's next row; the last from the extra rows
intro_copy_row:
    lda INTRO_DST
    sta zp_u
    lda INTRO_DST+1
    sta zp_u+1
    lda INTRO_ROW
    cmp #24
    beq @last
    lda INTRO_SRC
    sta zp_p1
    lda INTRO_SRC+1
    sta zp_p1+1
    jsr @copy
    lda INTRO_SRC               ; (the next row: 320 on)
    clc
    adc #<320
    sta INTRO_SRC
    lda INTRO_SRC+1
    adc #>320
    sta INTRO_SRC+1
    jmp @dst
@last:
    lda INTRO_XSRC
    sta zp_p1
    lda INTRO_XSRC+1
    sta zp_p1+1
    lda #$34
    sta $01
    jsr @copy
    lda #$35
    sta $01
    lda INTRO_XSRC
    clc
    adc #<320
    sta INTRO_XSRC
    lda INTRO_XSRC+1
    adc #>320
    sta INTRO_XSRC+1
@dst:
    lda INTRO_DST
    clc
    adc #<320
    sta INTRO_DST
    lda INTRO_DST+1
    adc #>320
    sta INTRO_DST+1
    rts
@copy:                          ; 320 bytes from zp_p1 to zp_u
    ldy #0
@a: lda (zp_p1),y
    sta (zp_u),y
    iny
    bne @a
    inc zp_p1+1
    inc zp_u+1
@b: lda (zp_p1),y
    sta (zp_u),y
    iny
    cpy #64
    bne @b
    rts
.endif

.if !INTRO_SCROLL
; intro_picture: zp_p1 = the compressed bitmap, A = the screen RAM byte (two of the three colours): unpack and show it
intro_picture:
    pha
    lda #0
    sta $d011                   ; (the screen is off while it unpacks)
    lda #<INTRO_BITMAP
    sta zp_u
    lda #>INTRO_BITMAP
    sta zp_u+1
    lda #<(INTRO_BITMAP + 8000)
    sta zp_ci
    lda #>(INTRO_BITMAP + 8000)
    sta zp_ci+1
    jsr intro_unpack
    pla                         ; the screen RAM: the colour of pixel value 01 in the high nibble, 10 in the low one
    jsr intro_fill_ram
    lda #IWHITE                 ; the colour RAM: pixel value 11
    ldx #>INTRO_COLOUR
    jsr intro_fill_screen
    lda #$48                    ; screen RAM at $d000, the bitmap at $e000
    sta $d018
    lda #$18
    sta $d016
    lda #$3b                    ; bitmap, on
    sta $d011
    rts

.endif

; intro_unpack: zp_p1 = the packed data (see tools/make_intro.py compress), zp_u = where to, zp_ci = where that ends
intro_unpack:
@tok:
    ldy #0
    lda (zp_p1),y
    tax
    inc zp_p1
    bne @n1
    inc zp_p1+1
@n1:
    txa                         ; (the flags again: from the token, not from the pointer)
    bmi @match
    sta zp_t                    ; a run of literals: this + 1 bytes
    ldy #0
@lit:
    lda (zp_p1),y
    sta (zp_u),y
    cpy zp_t
    beq @litdone
    iny
    bne @lit
@litdone:
    tya
    sec
    adc zp_p1
    sta zp_p1
    bcc @a1
    inc zp_p1+1
@a1:
    jmp @adv
@match:
    txa
    and #$40
    bne @far
    txa                         ; a copy of (token & 31) + 3 bytes from (the next byte) + 1 back
    and #$1f
    clc
    adc #2
    sta zp_t
    ldy #0
    lda (zp_p1),y
    inc zp_p1
    bne @a2
    inc zp_p1+1
@a2:
    sta zp_v
    clc
    lda zp_u
    sbc zp_v
    sta zp_v
    lda zp_u+1
    sbc #0
    sta zp_v+1
    jmp @copy
@far:                           ; a copy of (token & 63) + 4 bytes from a 16-bit offset back
    txa
    and #$3f
    clc
    adc #3
    sta zp_t
    ldy #0
    lda (zp_p1),y
    sta zp_v
    iny
    lda (zp_p1),y
    sta zp_v+1
    lda zp_p1
    clc
    adc #2
    sta zp_p1
    bcc @a3
    inc zp_p1+1
@a3:
    sec
    lda zp_u
    sbc zp_v
    sta zp_v
    lda zp_u+1
    sbc zp_v+1
    sta zp_v+1
@copy:
    ldy #0
@mc:
    lda (zp_v),y
    sta (zp_u),y
    cpy zp_t
    beq @adv
    iny
    bne @mc
@adv:
    tya
    sec
    adc zp_u
    sta zp_u
    bcc @a4
    inc zp_u+1
@a4:
    lda zp_u+1
    cmp zp_ci+1
    bcc @more
    lda zp_u
    cmp zp_ci
    bcs @done
@more:
    jmp @tok
@done:
    rts

; intro_rom_copy: zp_p1 = from, zp_u = to, X = pages: copied from the character ROM (the CPU sees it at $d000 with $01 = $31)
intro_rom_copy:
    lda #$31
    sta $01
    jsr copy_pages
    lda #$35
    sta $01
    rts

; intro_fill_ram: A = value: the screen RAM under the VIC-II's registers
intro_fill_ram:
    ldx #$34
    stx $01
    ldx #>INTRO_SCREEN
    jsr intro_fill_screen
    ldx #$35
    stx $01
    rts

; intro_fill_screen: A = value, X = the high byte of the 1000 bytes' address (four pages)
intro_fill_screen:
    stx zp_u+1
    ldy #0
    sty zp_u
    ldx #4
@l: sta (zp_u),y
    iny
    bne @l
    inc zp_u+1
    dex
    bne @l
    rts

; intro_textpage: zp_p1 = a table of texts (row, column, colour, the characters, 0; ends with row $ff), A = 1: with the
; logo strip (rows 2-6): a hires character screen with some multicolour characters
intro_textpage:
    sta INTRO_FLAGS
    lda zp_p1
    sta INTRO_TBL
    lda zp_p1+1
    sta INTRO_TBL+1
    lda #0
    sta $d011
    lda INTRO_FLAGS
    and #2
    bne @lower
    lda #<intro_charset_c       ; the redefined capitals and the strip's characters, unpacked to $e000...
    sta zp_p1
    lda #>intro_charset_c
    sta zp_p1+1
    lda #<INTRO_BITMAP
    sta zp_u
    lda #>INTRO_BITMAP
    sta zp_u+1
    lda #<(INTRO_BITMAP + 2048)
    sta zp_ci
    lda #>(INTRO_BITMAP + 2048)
    sta zp_ci+1
    jsr intro_unpack
    lda #<$d100                 ; ... and over the codes 32-63 the C64's own space, digits and punctuation
    sta zp_p1
    lda #>$d100
    sta zp_p1+1
    lda #<(INTRO_BITMAP + $100)
    sta zp_u
    lda #>(INTRO_BITMAP + $100)
    sta zp_u+1
    ldx #1
    bne @rom
@lower:
    lda #<$d800                 ; the C64's upper and lower case character set
    sta zp_p1
    lda #>$d800
    sta zp_p1+1
    lda #<INTRO_BITMAP
    sta zp_u
    lda #>INTRO_BITMAP
    sta zp_u+1
    ldx #8
@rom:
    jsr intro_rom_copy
    lda INTRO_TBL
    sta zp_p1
    lda INTRO_TBL+1
    sta zp_p1+1
    lda #' '
    jsr intro_fill_ram
    lda #IWHITE
    ldx #>INTRO_COLOUR
    jsr intro_fill_screen
    lda INTRO_FLAGS
    and #1
    beq @text
    lda #<intro_strip_c         ; the strip: 5 rows of 40 characters, multicolour (colour RAM $09)
    sta zp_p1
    lda #>intro_strip_c
    sta zp_p1+1
    lda #<INTRO_STRIPBUF
    sta zp_u
    lda #>INTRO_STRIPBUF
    sta zp_u+1
    lda #<(INTRO_STRIPBUF + 200)
    sta zp_ci
    lda #>(INTRO_STRIPBUF + 200)
    sta zp_ci+1
    jsr intro_unpack
    ldx #0
@s: lda INTRO_STRIPBUF,x
    ldy #$34
    sty $01
    sta INTRO_SCREEN + 80,x
    ldy #$35
    sty $01
    lda #$09
    sta INTRO_COLOUR + 80,x
    inx
    cpx #200
    bne @s
@text:
    lda INTRO_TBL               ; (the strip's unpacking used zp_p1)
    sta zp_p1
    lda INTRO_TBL+1
    sta zp_p1+1
    ldy #0
@entry:
    lda (zp_p1),y
    cmp #$ff
    beq @shown
    sta zp_t                    ; the row
    iny
    lda (zp_p1),y
    sta zp_v                    ; the column
    iny
    lda (zp_p1),y
    sta zp_v+1                  ; the colour
    iny
    sty zp_ci                   ; (the table's position)
    lda #<INTRO_SCREEN          ; zp_u = INTRO_SCREEN + row * 40 + column
    sta zp_u
    lda #>INTRO_SCREEN
    sta zp_u+1
    ldx zp_t
    beq @addcol
@row:
    lda zp_u
    clc
    adc #40
    sta zp_u
    bcc @r1
    inc zp_u+1
@r1:
    dex
    bne @row
@addcol:
    lda zp_u
    clc
    adc zp_v
    sta zp_u
    bcc @r2
    inc zp_u+1
@r2:
    ldy zp_ci
    ldx #0
@ch:
    lda (zp_p1),y
    beq @enddone
    pha
    lda #$34
    sta $01
    pla
    sta (zp_u,x)                ; (X = 0)
    lda #$35
    sta $01
    lda zp_u+1                  ; the same cell in colour RAM
    pha
    clc
    adc #>(INTRO_COLOUR - INTRO_SCREEN)
    sta zp_u+1
    lda zp_v+1
    sta (zp_u,x)
    pla
    sta zp_u+1
    inc zp_u
    bne @c1
    inc zp_u+1
@c1:
    iny
    bne @ch
@enddone:
    iny                         ; (on to the next entry: the table pointer moves, so that Y stays small)
    tya
    clc
    adc zp_p1
    sta zp_p1
    bcc @e1
    inc zp_p1+1
@e1:
    ldy #0
    jmp @entry
@shown:
    lda #0
    sta $d021
    lda #IRED
    sta $d022
    lda #IGREEN
    sta $d023
    lda #$48
    sta $d018
    lda #$18                    ; multicolour characters where colour RAM says so
    sta $d016
    lda #$1b                    ; text, on
    sta $d011
    rts

.segment "CODE"

.else

intro_run:
    rts

.endif
