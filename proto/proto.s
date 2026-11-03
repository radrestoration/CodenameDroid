; proto.s: a prototype of a C64-native engine for the game: tile background in character mode from a static character set,
; smooth sideways scrolling, and the player and three enemies as hardware sprites, walking by the BBC game's own rules
; (its checks of the bytes of the screen for walls, slopes, ground and ceiling; its jump). Level 1 (Surface Defence sector two).
;
; Nothing here converts what is drawn: the background is the level's character numbers (ROWS), looked up as the window moves.
; The window is moved by whole cells (the game's step) and by the VIC-II's fine scroll between them; the 40 x 25 screen
; matrix is rebuilt only when a cell boundary is crossed (one block copy and a new column, about 10,000 cycles), into the
; matrix that is not shown, and swapped in by the raster interrupt with the fine scroll and the sprites, so nothing tears.
;
; The border shows the time: blue is the game's step and the input, red the screen matrix being rebuilt, blue again the
; sprites; black is idle. Keys: Z / X walk, RETURN jumps (with Z or X for a jump to the side); joystick 2 as well.

.setcpu "6502"
.include "proto_data.inc"

ROWS        = $2800             ; 32 rows of 256 character numbers
BPAT        = $4800             ; the BBC bytes of the characters: line n of character c at BPAT + n * 256 + c
CHARSET     = $a000
MAT_A       = $a800
MAT_B       = $ac00
SPR0        = $c0               ; the sprite pointer of the first block at $b000 (VIC-II bank 2)

IRQLINE     = 20                ; in the top border: registers change before the display starts

; the window and the player
CENTER      = 17 * 8 * 16       ; where the player is on the screen (in 1/16 pixel)
MAXPOS      = 216 * 8 * 16      ; the furthest the window is scrolled
STEP_ACC    = 24                ; the game's step: 4 PAL frames, 4.8 NTSC (the accumulator gets 6 or 5 a frame)
NACT        = 4                 ; the player and three enemies

.segment "ZEROPAGE"
p1:         .res 2              ; pointers into ROWS and BPAT (the low byte stays 0)
p2:         .res 2
p4:         .res 2
p5:         .res 2
zi:         .res 1              ; the actor being done
zc:         .res 1              ; column for pixel
zl:         .res 1
zt:         .res 1
zk:         .res 1
zs:         .res 1
zm:         .res 1              ; set when an actor moved a cell
zd:         .res 1
zv:         .res 1

.segment "BSS"
tick:       .res 1              ; frames, from the interrupt
last_tick:  .res 1
dt:         .res 1
ready:      .res 1              ; 1 = the next frame's state (p_*) is complete
acc:        .res 1
add:        .res 1              ; 6 PAL, 5 NTSC
vel:        .res 1              ; pixels / 16 a frame: 32 PAL, 27 NTSC
keys:       .res 1              ; bit 0 left, 1 right, 2 jump
cur_buf:    .res 1              ; 0 = the latest matrix built is MAT_A, 1 = MAT_B
cur_w:      .res 1              ; the window's first cell column in it
cur_cam:    .res 1              ; and its first row
want_cam:   .res 1
t_w:        .res 1              ; the window the scroll position asks for
t_xs:       .res 1
spos_l:     .res 1              ; the scroll position, 1/16 pixel
spos_h:     .res 1
spx_l:      .res 1              ; and in pixels
spx_h:      .res 1
border:     .res 1

a_cx:       .res NACT           ; the actors: first cell column, top line
a_y:        .res NACT
a_dir:      .res NACT           ; 0 right, 1 left
a_frame:    .res NACT           ; 0-5
a_jt:       .res NACT
a_jdir:     .res NACT           ; 0 none, 1 right, 2 left
a_air:      .res NACT
a_want:     .res NACT           ; bit 0 left, 1 right, 2 jump
a_posl:     .res NACT           ; the position the sprite is at: 1/16 pixel
a_posh:     .res NACT
a_sy:       .res NACT           ; and the line

p_sx:       .res 8              ; the sprites for the next frame
p_sy:       .res 8
p_ptr:      .res 8
p_msb:      .res 1
p_en:       .res 1
p_d018:     .res 1
p_d016:     .res 1

; ------------------------------------------------------------------------------------------------
.segment "LOADADDR"
    .word $0801

.segment "STUB"
    .word @next
    .word 10
    .byte $9e, "2064", 0        ; 10 SYS 2064
@next:
    .word 0

.segment "CODE"
start:
    sei
    lda #0                      ; the variables
    tax
:   sta $0400,x
    sta $0500,x
    inx
    bne :-
    lda #$35                    ; RAM everywhere but the I/O area
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
    lda #0                      ; the low bytes of the pointers into ROWS and BPAT
    sta p1
    sta p2
    lda $dd00                   ; VIC-II bank 2: $8000-$bfff
    and #$fc
    ora #$01
    sta $dd00
    lda #$a8                    ; matrix at $a800, characters at $a000
    sta $d018
    lda #$1b                    ; text, 25 rows, DEN, YSCROLL 3
    sta $d011
    lda #$10                    ; multicolour, 38 columns (the border hides the fine scroll's edges), XSCROLL 0
    sta $d016
    lda #0
    sta $d020
    sta $d021                   ; BBC logical colour 0: black
    lda #2
    sta $d022                   ; 1: red
    lda #3
    sta $d023                   ; 2: cyan; 3 (white) is the colour RAM's, below
    lda #2
    sta $d025                   ; the sprites' multicolours: the same
    lda #1
    sta $d026
    lda #3
    ldx #7
:   sta $d027,x
    dex
    bpl :-
    lda #$ff
    sta $d01c                   ; multicolour sprites
    lda #0
    sta $d01b                   ; in front of the characters
    sta $d017
    sta $d01d
    lda #$09                    ; colour RAM: multicolour characters, white
    ldx #0
:   sta $d800,x
    sta $d900,x
    sta $da00,x
    sta $db00,x
    inx
    bne :-
    jsr detect_pal
    ; the game's step is 24 accumulator units: a PAL frame gives 6, an NTSC frame 5
    lda #6
    sta add
    lda #32
    sta vel
    lda c64_pal
    bne :+
    lda #5
    sta add
    lda #27
    sta vel
:
    jsr init_actors
    jsr init_view
    jsr compute_frame           ; the first frame, ready for the interrupt
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
    jmp main

c64_pal:    .byte 0

nmi:
    rti

; PAL has 312 lines: the raster counter's low byte passes $20 while its bit 8 is set; NTSC's 263 lines do not
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
    lda ready
    beq @done
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
    ldx #7
@p: lda p_ptr,x
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
@w: lda ready                   ; the interrupt has taken the last frame
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

; the state of the next frame: the game's steps that are due, the positions, the matrix, the sprites
compute_frame:
    lda #6
    sta $d020                   ; blue: the game
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
    jsr logic_step
    jmp @steps
@nostep:
    jsr smooth
    jsr calc_scroll
    lda #2
    sta $d020                   ; red: the screen matrix
    jsr matrix_update
    lda #6
    sta $d020
    jsr make_sprites
    lda #$10                    ; the fine scroll
    ora t_xs
    sta p_d016
    lda #0
    sta $d020
    lda #1
    sta ready
    rts

; ------------------------------------------------------------------------------------------------
; keys: Z, X, RETURN and joystick 2
read_keys:
    lda #0
    sta keys
    lda #$ff
    sta $dc00
    lda $dc00                   ; joystick 2: bit 2 left, 3 right, 4 fire, 0 when pressed
    tax
    and #$04
    bne :+
    lda keys
    ora #1
    sta keys
:   txa
    and #$08
    bne :+
    lda keys
    ora #2
    sta keys
:   txa
    and #$10
    bne :+
    lda keys
    ora #4
    sta keys
:   lda #%11111101              ; keyboard column 1: Z (row mask $10)
    sta $dc00
    lda $dc01
    and #$10
    bne :+
    lda keys
    ora #1
    sta keys
:   lda #%11111011              ; column 2: X ($80)
    sta $dc00
    lda $dc01
    and #$80
    bne :+
    lda keys
    ora #2
    sta keys
:   lda #%11111110              ; column 0: RETURN ($02)
    sta $dc00
    lda $dc01
    and #$02
    bne :+
    lda keys
    ora #4
    sta keys
:   lda #$ff
    sta $dc00
    rts

; ------------------------------------------------------------------------------------------------
; the level's bytes, as the game reads them: pixel gives the BBC byte of a cell column zc at a line (0-255)
pixel:
    sta zl
    lsr
    lsr
    lsr
    clc
    adc #>ROWS
    sta p1 + 1
    ldy zc
    lda (p1),y                  ; the character
    tay
    lda zl
    and #7
    clc
    adc #>BPAT
    sta p2 + 1
    lda (p2),y
    rts

; scan_col: the number of lines from line A down the cell column zc that are blank (0-32), a line below the level is a wall
scan_col:
    sta zt
    ldx #0
@l: txa
    clc
    adc zt
    bcs @r
    jsr pixel
    bne @r
    inx
    cpx #32
    bne @l
@r: rts

; ground: carry set if the actor zi has something under its three cells (the line below its feet)
ground:
    ldx zi
    lda a_cx,x
    sta zc
    lda a_y,x
    clc
    adc #32
    bcs @yes                    ; (the bottom of the level)
    sta zs
    lda #3
    sta zk
@k: lda zs
    jsr pixel
    bne @yes
    inc zc
    dec zk
    bne @k
    clc
    rts
@yes:
    sec
    rts

; above_blocked: carry set if something is on the line above the actor's head, in its three cells
above_blocked:
    ldx zi
    lda a_cx,x
    sta zc
    lda a_y,x
    sec
    sbc #4
    bcc @yes                    ; (the top of the level)
    sta zs
    lda #3
    sta zk
@k: lda zs
    jsr pixel
    bne @yes
    inc zc
    dec zk
    bne @k
    clc
    rts
@yes:
    sec
    rts

; try_move: the actor zi tries a step to the side: A = 0 right, 1 left. Carry set if it moved. Walls stop it; ground that
; rises by four or eight lines is climbed (the BBC's sloping ground)
try_move:
    sta zd
    ldx zi
    lda zd
    bne @left
    lda a_cx,x
    clc
    adc #3
    bcs @blocked
    cmp #255
    beq @blocked
    jmp @col
@left:
    lda a_cx,x
    beq @blocked
    sec
    sbc #1
@col:
    sta zc
    lda a_y,x
    jsr scan_col
    cpx #32
    beq @move
    cpx #24
    bcc @blocked
    txa
    and #3
    bne @blocked
    stx zv
    jsr above_blocked
    bcs @blocked
    ldx zi
    lda zv
    cmp #28
    bcs @once
    lda a_y,x
    sec
    sbc #4
    sta a_y,x
@once:
    lda a_y,x
    sec
    sbc #4
    sta a_y,x
@move:
    ldx zi
    lda zd
    sta a_dir,x
    bne @l2
    inc a_cx,x
    jmp @f
@l2:
    dec a_cx,x
@f: lda a_frame,x
    clc
    adc #1
    cmp #6
    bcc :+
    lda #0
:   sta a_frame,x
    lda #1
    sta zm
    sec
    rts
@blocked:
    clc
    rts

; horiz: an actor in the air moves a cell to the side if it is free (jdir 1 right, 2 left): if not, the jump is over
horiz:
    ldx zi
    lda a_jdir,x
    cmp #1
    bne @left
    lda a_cx,x
    clc
    adc #3
    bcs @stop
    jmp @col
@left:
    lda a_cx,x
    beq @stop
    sec
    sbc #1
@col:
    sta zc
    lda a_y,x
    jsr scan_col
    cpx #32
    bne @stop
    ldx zi
    lda a_jdir,x
    cmp #1
    bne @l2
    inc a_cx,x
    rts
@l2:
    dec a_cx,x
    rts
@stop:
    ldx zi
    lda #0
    sta a_jdir,x
    sta a_jt,x
    rts

; one step of the game for the actor zi (it is called every 4.8 frames): input or intent, then the jump or the fall
actor_step:
    ldx zi
    lda a_air,x
    bne @air
    lda a_want,x
    and #4
    beq @nojump
    lda #12                     ; the BBC's jump: 12 steps of four lines, 10 for a jump straight up
    sta a_jt,x
    lda a_want,x
    and #2
    beq :+
    lda #1
    sta a_jdir,x
    lda #0
    sta a_dir,x
    jmp @started
:   lda a_want,x
    and #1
    beq :+
    lda #2
    sta a_jdir,x
    lda #1
    sta a_dir,x
    jmp @started
:   lda #0
    sta a_jdir,x
    lda #10
    sta a_jt,x
@started:
    lda #1
    sta a_air,x
    jmp @air
@nojump:
    lda a_want,x
    and #2
    beq @notr
    lda #0
    jsr try_move
    jmp @fall
@notr:
    lda a_want,x
    and #1
    beq @stand
    lda #1
    jsr try_move
    jmp @fall
@stand:
    lda #0
    sta a_frame,x
@fall:
    jsr ground
    bcs @rts
    ldx zi
    lda #1
    sta a_air,x
    jmp @airfall
@air:
    ldx zi
    lda a_jt,x
    beq @airfall
    dec a_jt,x                  ; jumping up
    jsr above_blocked
    ldx zi
    bcc @free
    lda #0
    sta a_jt,x
    rts
@free:
    lda a_y,x
    sec
    sbc #4
    sta a_y,x
    lda #0
    sta a_frame,x
    lda a_jdir,x
    beq @rts
    jmp horiz
@airfall:
    ldx zi
    jsr ground
    ldx zi
    bcc @fall2
    lda #0                      ; landed
    sta a_air,x
    sta a_jdir,x
    sta a_jt,x
    rts
@fall2:
    lda #0
    sta a_frame,x
    lda a_jdir,x
    beq :+
    jsr horiz
    ldx zi
:   lda a_y,x
    clc
    adc #4
    sta a_y,x
@rts:
    rts

; the game's step for everyone, then the camera
logic_step:
    lda #0
    sta zi
@a: ldx zi
    bne @enemy
    lda keys
    sta a_want
    jmp @do
@enemy:
    lda a_dir,x                 ; patrol: on in the direction it faces, turn at a wall
    beq :+
    lda #1
    jmp @w
:   lda #2
@w: sta a_want,x
@do:
    lda #0
    sta zm
    jsr actor_step
    ldx zi
    beq @next
    lda a_air,x                 ; an enemy that did not move on the ground turns round
    bne @next
    lda zm
    bne @next
    lda a_dir,x
    eor #1
    sta a_dir,x
@next:
    inc zi
    lda zi
    cmp #NACT
    bne @a
    ; the camera: the player's top row in the 25 rows shown (the BBC window shows all 32: this keeps the player in view)
    lda a_y
    lsr
    lsr
    lsr
    sec
    sbc want_cam                ; row in the window
    bcc @up
    cmp #3
    bcc @up
    cmp #19
    bcs @down
    rts
@up:
    lda want_cam
    beq @r
    dec want_cam
@r: rts
@down:
    lda want_cam
    cmp #7
    bcs @r
    inc want_cam
    rts

; ------------------------------------------------------------------------------------------------
; the actors' positions move on to where the game put them: a step of vel (1/16 pixel) a frame, which is the game's speed
smooth:
    ldx #0
@a: lda a_cx,x                  ; target = cell * 128
    lsr
    sta zt                      ; high byte = cell / 2
    lda #0
    ror
    sta zs                      ; low byte
    lda zt
    cmp a_posh,x
    bcc @less
    bne @more
    lda zs
    cmp a_posl,x
    bcc @less
    beq @y
@more:                          ; target above the position: move up by vel, but not past
    lda zs
    sec
    sbc a_posl,x
    sta zd
    lda zt
    sbc a_posh,x
    bne @addv
    lda zd
    cmp vel
    bcc @set
    beq @set
@addv:
    lda a_posl,x
    clc
    adc vel
    sta a_posl,x
    bcc @y
    inc a_posh,x
    jmp @y
@less:
    lda a_posl,x
    sec
    sbc zs
    sta zd
    lda a_posh,x
    sbc zt
    bne @subv
    lda zd
    cmp vel
    bcc @set
    beq @set
@subv:
    lda a_posl,x
    sec
    sbc vel
    sta a_posl,x
    bcs @y
    dec a_posh,x
    jmp @y
@set:
    lda zs
    sta a_posl,x
    lda zt
    sta a_posh,x
@y: lda a_y,x                   ; the line: one a frame
    cmp a_sy,x
    beq @n
    bcc @dn
    inc a_sy,x
    jmp @n
@dn:
    dec a_sy,x
@n: inx
    cpx #NACT
    beq @fin
    jmp @a
@fin:
    rts

; the scroll position follows the player (clamped to the level): the window's first cell, and the fine scroll
calc_scroll:
    lda a_posl
    sec
    sbc #<CENTER
    sta spos_l
    lda a_posh
    sbc #>CENTER
    sta spos_h
    bcs @pos
    lda #0
    sta spos_l
    sta spos_h
    jmp @px
@pos:
    lda spos_h
    cmp #>MAXPOS
    bcc @px
    bne @max
    lda spos_l
    cmp #<MAXPOS
    bcc @px
@max:
    lda #<MAXPOS
    sta spos_l
    lda #>MAXPOS
    sta spos_h
@px:
    lda spos_h                  ; in pixels: / 16
    sta spx_h
    lda spos_l
    lsr spx_h
    ror
    lsr spx_h
    ror
    lsr spx_h
    ror
    lsr spx_h
    ror
    sta spx_l
    clc                         ; window = ceil(pixels / 8)
    adc #7
    sta zt
    lda spx_h
    adc #0
    lsr
    ror zt
    lsr
    ror zt
    lsr
    ror zt
    lda zt
    sta t_w
    asl                         ; fine scroll = 8 * window - pixels
    asl
    asl
    sec
    sbc spx_l
    sta t_xs
    rts

; ------------------------------------------------------------------------------------------------
; the matrices: MAT_A and MAT_B, the shown one and the one being built
.macro SHIFT dsta, srca, n3
    ldx #15
:
    .repeat 16, j
    lda srca + j * 16,x
    sta dsta + j * 16,x
    .endrepeat
    dex
    bpl :-
    ldx #15
:
    .repeat 16, j
    lda srca + $100 + j * 16,x
    sta dsta + $100 + j * 16,x
    .endrepeat
    dex
    bpl :-
    ldx #15
:
    .repeat 16, j
    lda srca + $200 + j * 16,x
    sta dsta + $200 + j * 16,x
    .endrepeat
    dex
    bpl :-
    ldx #15
:
    .repeat n3, j
    lda srca + $300 + j * 16,x
    sta dsta + $300 + j * 16,x
    .endrepeat
    dex
    bpl :-
.endmacro

; a column of the level into column 'col' of the matrix at dsta: 25 rows from the row the pointer p4 points at, cell Y
.macro NEWCOL dsta, col
    .repeat 25, r
    lda (p4),y
    sta dsta + col + 40 * r
    inc p4 + 1
    .endrepeat
.endmacro

; the 40 cells of a row of the level, from cell column zt, to the matrix row at p5
copy_row:
    ldy #39
@l: lda (p4),y
    sta (p5),y
    dey
    bpl @l
    rts

; the whole window, cur_w and cur_cam, into the matrix whose high byte is A
draw_full:
    sta p5 + 1
    lda #0
    sta p5
    sta p4
    lda cur_w
    sta p4                      ; the low byte of the pointer is the window's first column
    lda cur_cam
    clc
    adc #>ROWS
    sta p4 + 1
    lda #25
    sta zk
@r: jsr copy_row
    inc p4 + 1
    lda p5
    clc
    adc #40
    sta p5
    bcc :+
    inc p5 + 1
:   dec zk
    bne @r
    rts

init_view:
    lda #7
    sta cur_cam
    sta want_cam
    lda #0
    sta cur_buf
    jsr calc_scroll
    lda t_w
    sta cur_w
    lda #>MAT_A
    jsr draw_full
    lda #$a8
    sta p_d018
    rts

; make the matrix the window needs: one step at a time (a cell to the side, or a row), into the matrix not shown
matrix_update:
    lda cur_w
    cmp t_w
    beq @samew
    lda t_w
    sec
    sbc cur_w
    cmp #1
    bne :+
    jmp @left
:   cmp #$ff
    bne :+
    jmp @right
:   lda t_w                     ; a jump: all of it
    sta cur_w
    lda cur_buf
    eor #1
    sta cur_buf
    beq :+
    lda #>MAT_B
    jmp @full
:   lda #>MAT_A
@full:
    jsr draw_full
    jmp @shown
@samew:
    lda cur_cam
    cmp want_cam
    bne :+
    jmp @shown
:   bcc :+
    jmp @rowup
:   jmp @rowdown
@left:                          ; the window moves a cell right: the picture one cell left
    inc cur_w
    lda cur_buf
    beq :+
    jmp @left_b
:   SHIFT MAT_B, MAT_A + 1, 15
    jsr col_setup_right
    ldy zd
    NEWCOL MAT_B, 39
    jmp @swap
@left_b:
    SHIFT MAT_A, MAT_B + 1, 15
    jsr col_setup_right
    ldy zd
    NEWCOL MAT_A, 39
    jmp @swap
@right:
    dec cur_w
    lda cur_buf
    beq :+
    jmp @right_b
:   SHIFT MAT_B + 1, MAT_A, 15
    jsr col_setup_left
    ldy zd
    NEWCOL MAT_B, 0
    jmp @swap
@right_b:
    SHIFT MAT_A + 1, MAT_B, 15
    jsr col_setup_left
    ldy zd
    NEWCOL MAT_A, 0
    jmp @swap
@rowup:                         ; the camera moves up: the picture down a row
    dec cur_cam
    lda cur_buf
    beq :+
    jmp @rowup_b
:   SHIFT MAT_B + 40, MAT_A, 12
    lda #>MAT_B
    jmp @toprow
@rowup_b:
    SHIFT MAT_A + 40, MAT_B, 12
    lda #>MAT_A
@toprow:
    sta p5 + 1
    lda #0
    sta p5
    lda cur_w
    sta p4
    lda cur_cam
    clc
    adc #>ROWS
    sta p4 + 1
    jsr copy_row
    jmp @swap
@rowdown:
    inc cur_cam
    lda cur_buf
    beq :+
    jmp @rowdown_b
:   SHIFT MAT_B, MAT_A + 40, 15
    lda #>MAT_B
    jmp @botrow
@rowdown_b:
    SHIFT MAT_A, MAT_B + 40, 15
    lda #>MAT_A
@botrow:
    clc
    adc #>(24 * 40)             ; the last row: 24 * 40 = $3c0
    sta p5 + 1
    lda #<(24 * 40)
    sta p5
    lda cur_w
    sta p4
    lda cur_cam
    clc
    adc #24
    clc
    adc #>ROWS
    sta p4 + 1
    jsr copy_row
@swap:
    lda cur_buf
    eor #1
    sta cur_buf
@shown:
    lda cur_buf
    bne :+
    lda #$a8
    bne :++
:   lda #$b8
:   sta p_d018
    rts

; the pointer to the level's column for a new column at the right (cell cur_w + 39) or the left (cur_w)
col_setup_right:
    lda cur_w
    clc
    adc #39
    sta zd
    jmp col_ptr
col_setup_left:
    lda cur_w
    sta zd
col_ptr:
    lda #0
    sta p4
    lda cur_cam
    clc
    adc #>ROWS
    sta p4 + 1
    rts

; ------------------------------------------------------------------------------------------------
; the actors' sprites: two each (the upper 21 lines and the lower 11), at the actor's place on the screen
framemap:   .byte 0, 1, 2, 0, 3, 4

make_sprites:
    lda #0
    sta p_msb
    sta p_en
    ldx #0
@a: stx zi
    ; x on the screen: position in pixels minus the scroll
    lda a_posh,x
    sta zt
    lda a_posl,x
    lsr zt
    ror
    lsr zt
    ror
    lsr zt
    ror
    lsr zt
    ror                         ; pixels in zt:A
    sec
    sbc spx_l
    sta zs
    lda zt
    sbc spx_h
    sta zt                      ; screen x in zt:zs (signed)
    bmi @neg
    lda zt
    bne @maybe
    jmp @xok
@maybe:                         ; 256 or more: only up to 320
    cmp #2
    bcs @hj
    lda zs
    cmp #65
    bcs @hj
    jmp @xok
@neg:
    cmp #$ff
    bne @hj
    lda zs
    cmp #$e8                    ; -24
    bcs @xok
@hj:
    jmp @hide
@xok:
    lda zs                      ; sprite x = 24 + screen x (9 bits)
    clc
    adc #24
    sta zs
    lda zt
    adc #0
    sta zt
    ; y: line - 8 * camera, on the screen from 0 to 168
    lda a_sy,x
    sta zd
    lda cur_cam
    asl
    asl
    asl
    sta zk
    lda zd
    sec
    sbc zk
    bcc @hj
    cmp #169
    bcs @hj
    clc
    adc #50
    sta zk                      ; sprite y of the upper half
    ; the registers: sprites 2x and 2x+1
    txa
    asl
    tay                         ; y = sprite number
    lda zs
    sta p_sx,y
    sta p_sx + 1,y
    lda zk
    sta p_sy,y
    clc
    adc #21
    sta p_sy + 1,y
    ; the x high bit
    lda zt
    beq @nomsb
    lda bit2,y
    ora p_msb
    sta p_msb
    lda bit2 + 1,y
    ora p_msb
    sta p_msb
@nomsb:
    lda bit2,y
    ora p_en
    sta p_en
    lda bit2 + 1,y
    ora p_en
    sta p_en
    ; the block: kind (player 0, enemy 20), direction (left 0, right 10), frame, half
    lda #0
    cpx #0
    beq :+
    lda #20
:   sta zd
    lda a_dir,x
    beq :+
    lda #0                      ; facing left: the sprites as they are
    jmp @d
:   lda #10                     ; facing right: the mirrored ones
@d: clc
    adc zd
    sta zd
    lda a_frame,x
    tax
    lda framemap,x
    asl
    clc
    adc zd
    clc
    adc #SPR0
    sta p_ptr,y
    clc
    adc #1
    sta p_ptr + 1,y
@hide:
    ldx zi
    inx
    cpx #NACT
    beq @done
    jmp @a
@done:
    rts

bit2:       .byte $01, $02, $04, $08, $10, $20, $40, $80, $00

; ------------------------------------------------------------------------------------------------
init_actors:
    ; the player, then the enemies, on the floor
    lda #START_CX
    sta a_cx
    lda #START_Y
    sta a_y
    lda #ENEMY0_CX
    sta a_cx + 1
    lda #ENEMY0_Y
    sta a_y + 1
    lda #ENEMY1_CX
    sta a_cx + 2
    lda #ENEMY1_Y
    sta a_y + 2
    lda #ENEMY2_CX
    sta a_cx + 3
    lda #ENEMY2_Y
    sta a_y + 3
    ldx #0
@a: lda #0
    sta a_frame,x
    sta a_jt,x
    sta a_jdir,x
    sta a_air,x
    sta a_want,x
    lda a_y,x
    sta a_sy,x
    lda #1
    sta a_dir,x                 ; facing left
    lda a_cx,x                  ; position = cell * 128
    lsr
    sta a_posh,x
    lda #0
    ror
    sta a_posl,x
    inx
    cpx #NACT
    bne @a
    lda #0
    sta a_dir                   ; the player faces right
    sta acc
    sta ready
    sta last_tick
    rts

; ------------------------------------------------------------------------------------------------
.segment "BPAT"
    .incbin "bpat.bin"

.segment "ROWS"
    .incbin "rows.bin"

.segment "CHARSET"
    .incbin "charset.bin"

.segment "MATRICES"
    .res $800

.segment "SPRITES"
    .incbin "sprites.bin"
