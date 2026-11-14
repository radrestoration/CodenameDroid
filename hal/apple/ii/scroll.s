; Apple II HGR scrolling experiment. Z and X move the viewport one cell.
.setcpu "6502"
.export draw, world_x, scroll_left, scroll_right

.segment "ZEROPAGE"
map_ptr:    .res 2
screen_ptr: .res 2
world_x:    .res 1
row:        .res 1
line:       .res 1
edge_index: .res 1
edge_column: .res 1
edge_glyph: .res 1
direction:  .res 1

.segment "CODE"
start:
    sei
    cld
    bit $c054                   ; HGR page 1, full-screen graphics
    bit $c057
    bit $c052
    bit $c050
    lda #176
    sta world_x
    jsr draw
@keys:
    lda $c000
    bpl @keys
    bit $c010
    and #$7f
    cmp #'Z'
    beq @left
    cmp #'X'
    beq @right
    cmp #$08
    beq @left
    cmp #$15
    bne @keys
@right:
    jsr scroll_right
    jmp @keys
@left:
    jsr scroll_left
    jmp @keys

scroll_right:
    lda world_x
    cmp #216
    bcs @done
    inc world_x
    clc
    adc #40
    sta edge_index
    lda #39
    sta edge_column
    lda #32
    sta direction
    jmp shift_screen
@done:
    rts

scroll_left:
    lda world_x
    beq @done
    dec world_x
    sec
    sbc #1
    sta edge_index
    lda #0
    sta edge_column
    sta direction
    jmp shift_screen
@done:
    rts

shift_screen:
    lda #0
    sta line
    sta map_ptr
    lda #>world
    sta map_ptr + 1
    lda #>glyphs
    sta edge_load + 2
shift_row:
    ldy edge_index
    lda (map_ptr),y
    sta edge_glyph
shift_scan:
    ldx line
    lda screen_lo,x
    sta edge_store + 1
    lda screen_hi,x
    sta edge_store + 2
    lda shift_index,x
    clc
    adc direction
    tax
    lda shift_lo,x
    sta shift_call + 1
    lda shift_hi,x
    sta shift_call + 2
    ldx line
    lda shift_offset,x
    tax
shift_call:
    jsr $ffff
    ldy edge_glyph
edge_load:
    lda glyphs,y
    ldx edge_column
edge_store:
    sta $ffff,x
    inc line
    lda line
    and #7
    beq shift_next_row
    inc edge_load + 2
    jmp shift_scan
shift_next_row:
    lda #>glyphs
    sta edge_load + 2
    inc map_ptr + 1
    lda line
    cmp #192
    bne shift_row
    rts

draw:
    lda #0
    sta row
    sta line
    sta map_ptr
    lda #>world
    sta map_ptr + 1
draw_row:
    ldx line
    lda screen_lo,x
    sta screen_ptr
    lda screen_hi,x
    sta screen_ptr + 1
    lda #>glyphs
    sta glyph_load + 2
    ldx #8
draw_scan:
    ldy #0
draw_cell:
    tya
    clc
    adc world_x
    tay
    lda (map_ptr),y
    tay
glyph_load:
    lda glyphs,y
    ldy column
    sta (screen_ptr),y
    inc column
    ldy column
    cpy #40
    bne draw_cell
    lda #0
    sta column
    inc glyph_load + 2
    inc line
    cpx #1
    beq :+
    ldy line
    lda screen_lo,y
    sta screen_ptr
    lda screen_hi,y
    sta screen_ptr + 1
:   
    dex
    bne draw_scan
    inc map_ptr + 1
    inc row
    lda row
    cmp #24
    bne draw_row
    rts

column: .byte 0
screen_lo:
    .repeat 192, scanline
        .byte <($2000 + (scanline .mod 8) * $400 + ((scanline / 8) .mod 8) * $80 + (scanline / 64) * 40)
    .endrepeat
screen_hi:
    .repeat 192, scanline
        .byte >($2000 + (scanline .mod 8) * $400 + ((scanline / 8) .mod 8) * $80 + (scanline / 64) * 40)
    .endrepeat

shift_index:
    .repeat 192, scanline
        .byte ((scanline / 8) .mod 8 / 2) * 8 + (scanline .mod 8)
    .endrepeat
shift_offset:
    .repeat 192, scanline
        .byte (((scanline / 8) .mod 2) * 128) + ((scanline / 64) * 40)
    .endrepeat
shift_lo:
    .repeat 32, n
        .byte <.ident(.sprintf("shift_right_%d", n))
    .endrepeat
    .repeat 32, n
        .byte <.ident(.sprintf("shift_left_%d", n))
    .endrepeat
shift_hi:
    .repeat 32, n
        .byte >.ident(.sprintf("shift_right_%d", n))
    .endrepeat
    .repeat 32, n
        .byte >.ident(.sprintf("shift_left_%d", n))
    .endrepeat

; Each routine shifts eight scanlines within a pair of character rows.
; X selects the row within the pair and the screen's 64-line band.
.repeat 32, n
    .ident(.sprintf("shift_right_%d", n)):
    .repeat 39, col
        lda $2000 + (n .mod 8) * $400 + (n / 8) * $100 + 38 - col,x
        sta $2000 + (n .mod 8) * $400 + (n / 8) * $100 + 39 - col,x
    .endrepeat
    rts
    .ident(.sprintf("shift_left_%d", n)):
    .repeat 39, col
        lda $2000 + (n .mod 8) * $400 + (n / 8) * $100 + 1 + col,x
        sta $2000 + (n .mod 8) * $400 + (n / 8) * $100 + col,x
    .endrepeat
    rts
.endrepeat

.align 256
glyphs:
    .incbin "build/apple2/glyphs.bin"
.align 256
world:
    .incbin "build/apple2/world.bin"
