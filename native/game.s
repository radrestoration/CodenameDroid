; Codename Droid, C64-native engine: the BBC game's rules on a character-mode display with smooth scrolling.
; The level is a window onto ROWS (32 rows of 256 character numbers) made at level load from the BBC's own tiles; the player is
; hardware sprites; enemies, objects and mines are characters written into ROWS (and the two screen matrices) as they change; the
; blasters are sprites. The rules are the BBC game's (bbc/src/droid.s), ported routine by routine; the names follow it.

.setcpu "6502"
.include "native_data.inc"

; ---- memory
BPAT        = $ee00             ; the BBC bytes of each character: line n of character c at BPAT + n * 256 + c
HEAD        = $f600             ; character sharing: hash chains
NXT         = $f700
TG          = $f800             ; the level's tile grids: 16 characters for each of the 16 nibbles
TGALT       = $f900             ; the chandelier turned the other way
ROWS        = $a000             ; 32 rows of 256 characters ($a000-$bfff)
CHARSET     = $c000             ; VIC-II bank 3
MAT_A       = $c800
MAT_B       = $cc00
RIDE_CHARSET = $d000            ; lift display charset; ride sprites are staged at $de80
RIDE_MAT_A  = MAT_A
RIDE_MAT_B  = MAT_B
STAGE_CHARSET = $d800           ; next level's charset while the ride is displayed
SPRAREA     = $d000             ; the sprite blocks, copied under the I/O area at start
SPRBASE     = $40               ; their pointer base
D018_A      = $20
D018_B      = $30
RIDE_D018_A = $24
RIDE_D018_B = $34
LTILES      = $e000             ; the 14 levels' tile maps as they stand (a page each: $e000-$edff)
MIRROR_TABLE = $0600            ; a byte with its four two-bit pixels in the other order (made at start)
mirror_table = MIRROR_TABLE
SND         = $fa00             ; the sound driver's variables

MAXCH       = 204               ; characters 1 - 203 are the level's; 253 - 255 the mine
CH_EXPL1    = 253
CH_EXPL0    = 254
CH_MINE     = 255

IRQLINE     = 20
CENTER      = 17 * 8 * 16       ; where the player is on the screen (1/16 pixel)
MAXPOS      = 216 * 8 * 16
STEP_ACC    = 24

; keys (one byte each in `keys` as bits; `key1` and `key2` give the order of pressing)
K_RIGHT     = 1                 ; X
K_LEFT      = 2                 ; Z
K_UP        = 3
K_DOWN      = 4
K_TERM      = 5                 ; A
K_JET       = 6                 ; J
K_JUMP      = 7                 ; RETURN
K_FIRE      = 8
K_ESC       = 9
K_F0        = 10
K_F1        = 11
K_PAUSE     = 12
K_MINE      = 13                ; D
K_TAB       = 14
K_O         = 15
K_SPACE     = 16
K_S         = 17
K_B         = 18
K_M         = 19

.segment "ZEROPAGE"
p1:         .res 2
p2:         .res 2
p3:         .res 2
p4:         .res 2
p5:         .res 2
cb:         .res 8              ; a cell being made
zc:         .res 1
zl:         .res 1
zt:         .res 1
zk:         .res 1
zs:         .res 1
zm:         .res 1
zd:         .res 1
zv:         .res 1
zr:         .res 1
zf:         .res 1
zy:         .res 1
zx:         .res 1
sa_c:       .res 1              ; the BBC's screen_address, as a cell column and a line
sa_l:       .res 1

.segment "BSS"
tick:       .res 1
last_tick:  .res 1
dt:         .res 1
ready:      .res 1
acc:        .res 1
add:        .res 1
c64_pal:    .res 1
keys:       .res 3              ; the keys held: bit n - 1 of the three bytes is key n
key1:       .res 1              ; the most recently pressed key (0 none), key2 the first pressed that is still held
key2:       .res 1
nchars:     .res 1
level:      .res 1
cur_buf:    .res 1
cur_w:      .res 1
cur_cam:    .res 1
want_cam:   .res 1
mat_w:      .res 2              ; the window of each matrix
mat_c:      .res 2
t_w:        .res 1
t_xs:       .res 1
spos_l:     .res 1
spos_h:     .res 1
spx_l:      .res 1
spx_h:      .res 1
p_sx:       .res 8
p_sy:       .res 8
p_ptr:      .res 8
p_msb:      .res 1
p_en:       .res 1
p_d018:     .res 1
p_d016:     .res 1
p_dd00:     .res 1
p_spr_base: .res 1
p_d010x:    .res 1
p_xexp:     .res 1
overflow:   .res 1

.include "state.inc"
os_sound_suppression = sound_off

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
    ; mirror_table[b]: the bits of each nibble reversed
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

rev_nibble: .byte 0, 8, 4, 12, 2, 10, 6, 14, 1, 9, 5, 13, 3, 11, 7, 15

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

; Sprite sources are in the PRG; copy them under I/O so VIC bank 3 can fetch them at $d000.
copy_sprites:
    lda #<sprite_blocks
    sta p1
    lda #>sprite_blocks
    sta p1 + 1
    lda #<SPRAREA
    sta p2
    lda #>SPRAREA
    sta p2 + 1
    lda #$34
    sta $01                     ; RAM under the I/O area
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
    lda #$35
    sta $01
    rts

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
main:
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
    jmp main

; the border shows the time in a build with PROFILE: blue the game, red the screen matrix, black idle
.macro BORDER colour
.ifdef PROFILE
    lda #colour
    sta $d020
.endif
.endmacro

compute_frame:
    BORDER 6
    jsr read_keys
    lda dt
    beq @steps
    tax
:   lda acc
    clc
    adc add
    sta acc
    dex
    bne :-
@steps:
    lda acc
    cmp #STEP_ACC
    bcc @nostep
    sec
    sbc #STEP_ACC
    sta acc
    jsr game_step
    jmp @steps
@nostep:
    jsr smooth
    jsr calc_scroll
    BORDER 2
    jsr matrix_update
    BORDER 6
    jsr make_sprites
    lda #$10
    ora t_xs
    sta p_d016
    BORDER 0
    lda #1
    sta ready
    rts

.include "level.s"
.include "view.s"
.include "input.s"
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
