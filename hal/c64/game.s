; Codename Droid, C64 version: the BBC game's rules on a character-mode display with smooth scrolling.
; The level is a window onto ROWS (32 rows of 256 character numbers) made at level load from the BBC's own tiles; the player is
; hardware sprites; enemies, objects and mines are characters written into ROWS (and the two screen matrices) as they change; the
; blasters are sprites. The rules are the BBC game's (bbc/src/droid.s), ported routine by routine; the names follow it.

.setcpu "6502"
.include "game_data.inc"

.include "memory.inc"
.include "constants.inc"
.include "hal.inc"
.include "vars.inc"

.segment "LOADADDR"
    .word $0801

.segment "STUB"
    .word @next
    .word 10
    .byte $9e, "2064", 0
@next:
    .word 0

.segment "CODE"
start:
    sei
    lda #0
    tax
:   sta $0200,x
    sta $0300,x
    sta $0400,x
    sta $0500,x
    sta $0600,x
    sta $0700,x
    inx
    bne :-
    jsr init_mirror_table
    lda #$35
    sta $01
    lda #<irq
    sta $fffe
    lda #>irq
    sta $ffff
    lda #<nmi
    sta $fffa
    lda #>nmi
    sta $fffb
    lda #$7f
    sta $dc0d
    sta $dd0d
    lda $dc0d
    lda $dd0d
    lda #0
    sta $d01a
    sta $d015
    lda $dd00
    and #$fc
    sta $dd00                   ; VIC-II bank 3
    sta p_dd00
    lda #SPRBASE
    sta p_spr_base
    lda #D018_A
    sta $d018
    lda #$1b
    sta $d011
    lda #$10
    sta $d016
    lda #0
    sta $d020
    sta $d021
    lda #2
    sta $d022
    lda #3
    sta $d023
    lda #2
    sta $d025
    lda #1
    sta $d026
    lda #3
    ldx #7
:   sta $d027,x
    dex
    bpl :-
    lda #$ff
    sta $d01c
    lda #0
    sta $d01b
    sta $d017
    sta $d01d
    lda #$09
    ldx #0
:   sta $d800,x
    sta $d900,x
    sta $da00,x
    sta $db00,x
    inx
    bne :-
    jsr detect_pal
    jsr snd_init
    lda #6
    sta add
    lda c64_pal
    bne :+
    lda #5
    sta add
:   jsr clear_buffers
    lda #>ROWS
    sta rows_page
    jsr copy_sprites
    lda #IRQLINE
    sta $d012
    lda $d011
    and #$7f
    sta $d011
    lda #1
    sta $d01a
    lda $d019
    sta $d019
    cli
    jmp restart_game

nmi:
    rti

detect_pal:
    lda #0
    sta c64_pal
    tax
    tay
@l: lda $d011
    bpl @n
    lda $d012
    cmp #$20
    bcc @n
    lda #1
    sta c64_pal
@n: inx
    bne @l
    iny
    cpy #$20
    bne @l
    rts

; ------------------------------------------------------------------------------------------------
irq:
    pha
    txa
    pha
    tya
    pha
    lda #1
    sta $d019
    inc tick
    jsr snd_frame
    lda ready
    beq @done
    lda p_dd00
    sta $dd00
    lda p_d018
    sta $d018
    lda p_d016
    sta $d016
    ldx #0
    ldy #0
@s: lda p_sx,x
    sta $d000,y
    lda p_sy,x
    sta $d001,y
    iny
    iny
    inx
    cpx #8
    bne @s
    lda p_msb
    sta $d010
    lda p_en
    sta $d015
    lda p_xexp
    sta $d01d
    ldx #7
@p: lda p_ptr,x
    clc
    adc p_spr_base
    sta MAT_A + $3f8,x
    sta MAT_B + $3f8,x
    dex
    bpl @p
    lda #0
    sta ready
@done:
    pla
    tay
    pla
    tax
    pla
    rti

; ------------------------------------------------------------------------------------------------
hal_main:
@w: lda ready
    bne @w
    lda tick
    sec
    sbc last_tick
    sta dt
    lda tick
    sta last_tick
    lda dt
    cmp #4
    bcc :+
    lda #3
    sta dt
:   jsr compute_frame
    jmp hal_main

.include "frame.s"
.include "init.s"

.include "level.s"
.include "view.s"
.include "input.s"
.include "keys.s"
.include "charset.s"
.include "timing.s"
.include "player.s"
.include "objects.s"
.include "enemy.s"
.include "blaster.s"
.include "events.s"
.include "lift.s"
.include "screens.s"
.include "title.s"
.ifdef CHEAT
.include "cheat.s"
.endif
.include "sfx.s"
.include "sound.s"
