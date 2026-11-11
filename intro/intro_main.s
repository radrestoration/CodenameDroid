; The loading screens as a program of their own (the BBC disc's front end: instruction pages, the logo, the pictures, the credits):
; it is run first, and when SPACE starts the game it loads the game (GAME) over itself and runs it. The code that does that is
; kept at $0334, which the game's file does not cover. Built by `make intro`.

.setcpu "6502"
; the loading screens' own variables: the zero page and low memory (the game is not loaded yet)
zp_p1       = $d0           ; 2
zp_ci       = $d2           ; 2
zp_h        = $d5
zp_t        = $d7
zp_u        = $d8           ; 2
zp_d        = $f1           ; 2
zp_idx      = $f3           ; 2
zp_v        = $f5           ; 2
c64_pal     = $0205         ; 1 = PAL (50 Hz), 0 = NTSC (60 Hz)
kb_rows     = $0230         ; 8: the keyboard matrix rows read for each column (0 bits = pressed)
kb_new      = $0238         ; 12: codes pressed in this scan, kb_nnew of them
kb_held     = $0244         ; 4: held game keys, oldest first
kb_nheld    = $0248
kb_nnew     = $0249
kb_ascii    = $024a         ; ASCII of the first key newly pressed in the last scan (0 = none)
kb_joy      = $024b
kb_tmp      = $024c
kb_prev     = $0280         ; 9: the keyboard rows and joystick as the last scan with a change saw them
os_most_recently_pressed_key = $ec
os_first_pressed_key         = $ed

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
    ldx #0
    lda #0
:   sta $0200,x                 ; (the loading screens' variables are at $0270-$02ff)
    inx
    bne :-
    lda $ba
    cmp #8
    bcc @default_device
    cmp #12
    bcc @save_device
@default_device:
    lda #8                      ; a PRG autostart may not have a disk device in $ba
@save_device:
    sta loader_src              ; (its first byte: the device the loading screens came from)
    lda #$35
    sta $01
    lda #$7f
    sta $dc0d
    sta $dd0d
    lda $dc0d
    lda $dd0d
    lda #0
    sta $d01a
    sta $d015
    ; PAL or NTSC: the raster counter's bit 8 is set at line $20 and over on PAL (312 lines) only
    lda #0
    sta c64_pal
    tax
    tay
@p: lda $d011
    bpl @n
    lda $d012
    cmp #$20
    bcc @n
    lda #1
    sta c64_pal
@n: inx
    bne @p
    iny
    cpy #$20
    bne @p
    jsr intro_run
    ; the loader to $0334, then run it
    ldx #loader_end - loader_src - 1
@c: lda loader_src,x
    sta $0334,x
    dex
    bpl @c
    jmp $0334 + 1               ; (past the saved device number)

; (runs at $0334: the game's file loads over everything else)
loader_src:
    .byte 8
    sei
    lda #$37
    sta $01
    lda $0334
    sta $ba                     ; the device the loading screens came from
    lda #4
    ldx #<($0334 + (loader_name - loader_src))
    ldy #>($0334 + (loader_name - loader_src))
    jsr $ffbd                   ; SETNAM
    lda #1
    ldx $ba
    ldy #1                      ; load where the file says
    jsr $ffba                   ; SETLFS
    lda #0
    jsr $ffd5                   ; LOAD
    bcs loader_error
    jmp $0810
loader_name:
    .byte "GAME"
loader_error:
    and #$0f
    ora #$30
    sta $0400 + 24
    lda $dd00
    ora #3
    sta $dd00                   ; VIC bank 0, screen at $0400
    lda #$14
    sta $d018
    lda #$c8
    sta $d016
    lda #$1b
    sta $d011
    lda #0
    sta $d021
    ldx #23
@message:
    lda loader_error_text - loader_src + $0334,x
    sta $0400,x
    lda #1
    sta $d800,x
    dex
    bpl @message
    lda #1
    sta $d800 + 24
@stop:
    jmp $0334 + (@stop - loader_src)
loader_error_text:
    .byte 12,15,1,4,32,7,1,13,5,32,6,1,9,12,5,4,32,5,18,18,15,18,32,32
loader_end:
    .assert loader_end - loader_src <= 128, error, "relocated loader exceeds copy loop"

KEY_JOY_UP      = $c8
KEY_JOY_DOWN    = $e8
KEY_JOY_LEFT    = $e1
KEY_JOY_RIGHT   = $c2
KEY_JOY_FIRE    = $c9

NKEYS = 21
keytab:
    .byte 1, $10, $e1, 'Z'      ; Z
    .byte 2, $80, $c2, 'X'      ; X
    .byte 6, $04, $c8, ';'      ; ; = up
    .byte 6, $80, $e8, '/'      ; /
    .byte 0, $02, $c9, $0d      ; RETURN
    .byte 6, $20, $d8, '='      ; = = fire the blaster
    .byte 7, $10, $e2, ' '      ; SPACE
    .byte 1, $04, $c1, 'A'      ; A
    .byte 4, $04, $c5, 'J'      ; J
    .byte 1, $20, $90, 'S'      ; S
    .byte 3, $10, $91, 'B'      ; B
    .byte 4, $10, $92, 'M'      ; M
    .byte 2, $04, $b2, 'D'      ; D
    .byte 4, $40, $b6, 'O'      ; O
    .byte 5, $02, $e9, 'P'      ; P = COPY
    .byte 0, $01, $d9, $14      ; DEL = DELETE
    .byte 7, $04, $e0, 0        ; CTRL = TAB
    .byte 7, $80, $f0, 3        ; RUN/STOP = ESCAPE
    .byte 0, $10, $a0, 0        ; F1 = f0
    .byte 0, $20, $f1, 0        ; F3 = f1
    .byte 3, $80, $e3, 'V'      ; V (the loading screens' controls page; the game has no use for the code)

colsel:
    .byte $fe, $fd, $fb, $f7, $ef, $df, $bf, $7f

c64_scan_keys:
    ; ---- joystick 2 (port A of CIA 1, read with the lines as inputs) ----
    lda #0
    sta $dc02
    lda $dc00
    sta kb_joy
    lda #$ff
    sta $dc02
    ; ---- keyboard: the rows for each column ----
    ldx #7
@col:
    lda colsel,x                ; a 0 bit in column X
    sta $dc00
    lda $dc01
    sta kb_rows,x
    dex
    bpl @col
    lda #$ff
    sta $dc00
    ; ---- nothing pressed or released since the last scan: the held keys are as they were (this is most scans:
    ; it saves 1,500 of the interrupt's cycles) ----
    ldx #7
@same:
    lda kb_rows,x
    cmp kb_prev,x
    bne @changed
    dex
    bpl @same
    lda kb_joy
    cmp kb_prev + 8
    bne @changed
    rts
@changed:
    ldx #7
@save:
    lda kb_rows,x
    sta kb_prev,x
    dex
    bpl @save
    lda kb_joy
    sta kb_prev + 8
    ; ---- which codes are down, in table order (kb_new) ----
    lda #0
    sta kb_nnew
    ldy #0                      ; table offset
@ent:
    ldx keytab,y                ; column
    lda kb_rows,x
    and keytab+1,y
    bne @next                   ; 1 = not pressed
    lda keytab+2,y
    jsr @add
@next:
    iny
    iny
    iny
    iny
    cpy #NKEYS*4
    bne @ent
    ; joystick: bits 0-4 = up, down, left, right, fire; 0 = pressed
    lda kb_joy
    and #$01
    bne @j1
    lda #KEY_JOY_UP
    jsr @add
@j1:
    lda kb_joy
    and #$02
    bne @j2
    lda #KEY_JOY_DOWN
    jsr @add
@j2:
    lda kb_joy
    and #$04
    bne @j3
    lda #KEY_JOY_LEFT
    jsr @add
@j3:
    lda kb_joy
    and #$08
    bne @j4
    lda #KEY_JOY_RIGHT
    jsr @add
@j4:
    lda kb_joy
    and #$10
    bne @merge
    lda #KEY_JOY_FIRE
    jsr @add
@merge:
    ; ---- the keys still held, oldest first, then the newly pressed ones ----
    ; (a new key's ASCII is kept for OSRDCH)
    ldx #0                      ; X = index into the old held list
    ldy #0                      ; Y = number kept (written back over the list)
@keep:
    cpx kb_nheld
    beq @addnew
    stx kb_tmp
    lda kb_held,x
    jsr @innew                  ; clobbers X
    bne @drop
    ldx kb_tmp
    lda kb_held,x
    sta kb_held,y
    iny
@drop:
    ldx kb_tmp
    inx
    jmp @keep
@addnew:
    sty kb_nheld
    ldx #0
@nl:
    cpx kb_nnew
    beq @done
    lda kb_new,x
    stx kb_tmp
    jsr @inheld                 ; Z set if it is already held
    bne @isnew
    ldx kb_tmp
    inx
    jmp @nl
@isnew:
    ldx kb_tmp
    lda kb_new,x
    ldy kb_nheld
    cpy #4
    bcs @full
    sta kb_held,y
    inc kb_nheld
    ; ASCII of the first newly pressed key, for OSRDCH
    lda kb_ascii
    bne @full
    lda kb_new,x
    jsr @ascii_of
    sta kb_ascii
@full:
    ldx kb_tmp
    inx
    jmp @nl
@done:
    ; ---- the two OS variables ----
    lda kb_nheld
    beq @none
    lda kb_held
    sta os_first_pressed_key
    ldx kb_nheld
    lda kb_held-1,x
    sta os_most_recently_pressed_key
    rts
@none:
    lda #0
    sta os_first_pressed_key
    sta os_most_recently_pressed_key
    rts

; @add: append the code in A to kb_new (at most 12)
@add:
    ldx kb_nnew
    cpx #12
    bcs @addret
    sta kb_new,x
    inc kb_nnew
@addret:
    rts
; @innew: is the code in A in kb_new? Z = 0 if not found... returns Z clear (bne) if NOT found
@innew:
    ldx #0
@in1:
    cpx kb_nnew
    beq @notfound
    cmp kb_new,x
    beq @found
    inx
    jmp @in1
@found:
    lda #0                      ; Z set: found
    rts
@notfound:
    lda #1                      ; Z clear: not found
    rts
; @inheld: is the code in A in kb_held? Z set if found
@inheld:
    ldx #0
@ih1:
    cpx kb_nheld
    beq @ihno
    cmp kb_held,x
    beq @ihyes
    inx
    jmp @ih1
@ihyes:
    lda #0
    rts
@ihno:
    lda #1
    rts
; @ascii_of: the ASCII for the BBC code in A (0 if none)
@ascii_of:
    ldy #0
@ao:
    cmp keytab+2,y
    beq @aofound
    iny
    iny
    iny
    iny
    cpy #NKEYS*4
    bne @ao
    lda #0
    rts
@aofound:
    lda keytab+3,y
    rts


; copy_pages: X pages from zp_p1 to zp_u
copy_pages:
    ldy #0
@l: lda (zp_p1),y
    sta (zp_u),y
    iny
    bne @l
    inc zp_p1+1
    inc zp_u+1
    dex
    bne @l
    rts

.include "../src/intro.s"
