; Start-up pieces every platform needs.

; init_mirror_table: MIRROR_TABLE[b] = the bits of each nibble of b reversed
init_mirror_table:
    ldx #0
:   txa
    lsr
    lsr
    lsr
    lsr
    tay
    lda rev_nibble,y
    asl
    asl
    asl
    asl
    sta zt
    txa
    and #$0f
    tay
    lda rev_nibble,y
    ora zt
    sta MIRROR_TABLE,x
    inx
    bne :-
    rts

rev_nibble: .byte 0, 8, 4, 12, 2, 10, 6, 14, 1, 9, 5, 13, 3, 11, 7, 15

; Sprite sources are in the program; copy them to SPRAREA (on the C64 under the I/O area, where VIC bank 3 can fetch them).
copy_sprites:
    lda #<sprite_blocks
    sta p1
    lda #>sprite_blocks
    sta p1 + 1
    lda #<SPRAREA
    sta p2
    lda #>SPRAREA
    sta p2 + 1
    HAL_RAM_UNDER_IO
    ldx #>(SPR_BLOCKS * 64 + 255)
    ldy #0
:   lda (p1),y
    sta (p2),y
    iny
    bne :-
    inc p1 + 1
    inc p2 + 1
    dex
    bne :-
    HAL_IO_VISIBLE
    rts

; clear_buffers: BPAT (the characters' BBC bytes) and the platform's character set
clear_buffers:
    lda #0
    sta p1
    lda #>BPAT
    sta p1 + 1
    ldy #0
    ldx #8
:   lda #0
    sta (p1),y
    iny
    bne :-
    inc p1 + 1
    dex
    bne :-
    jmp hal_clear_charset
