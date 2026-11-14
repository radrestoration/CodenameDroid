; The C64's character set: the BBC bytes of a character (cb, and in BPAT) are converted into the VIC-II's multicolour form here.
; The set being made is at charset_page: the live set, or while a lift ride is shown the staging area for the next level's.

.segment "CODE"

; hal_store_char: character Y has its 8 BBC bytes in cb (and BPAT): put it in the character set. Clobbers A, X, Y, p5.
hal_store_char:
    lda #0
    sta p5 + 1
    tya
    asl
    rol p5 + 1
    asl
    rol p5 + 1
    asl
    rol p5 + 1
    sta p5
    lda p5 + 1
    clc
    adc charset_page
    sta p5 + 1
    lda charset_page
    cmp #>STAGE_CHARSET
    bne @write
    sei
    lda #$34
    sta $01
@write:
    ldy #7
:   ldx cb,y
    lda conv_table,x
    sta (p5),y
    dey
    bpl :-
    lda charset_page
    cmp #>STAGE_CHARSET
    bne @done
    lda #$35
    sta $01
    cli
@done:
    rts

; hal_charset_reset: the characters about to be made go to the live set; during a lift ride, to the staging area (its blank
; character is cleared)
hal_charset_reset:
    lda lift_screen
    beq @normal
    lda #>STAGE_CHARSET
    sta charset_page
    ; the staging area holds the sprite blocks: the blank character must be cleared
    php
    sei
    lda $01
    pha
    lda #$34
    sta $01
    lda #0
    ldx #7
:   sta STAGE_CHARSET,x
    dex
    bpl :-
    pla
    sta $01
    plp
    rts
@normal:
    lda #>CHARSET
    sta charset_page
    rts

; hal_clear_charset: the live character set (8 pages) to zero
hal_clear_charset:
    lda #0
    sta p1
    ldy #0
    lda #>CHARSET
    sta p1 + 1
    ldx #8
:   lda #0
    sta (p1),y
    iny
    bne :-
    inc p1 + 1
    dex
    bne :-
    rts
