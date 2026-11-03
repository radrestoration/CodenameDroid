; ---- keyboard and joystick (port 2): the keys held as bits, and the order they were pressed in (the BBC game looks at the most
; recently pressed key and the first pressed key)

.segment "BSS"
heldord:    .res 4
.segment "CODE"

; column select, row mask, key number
keytab:
    .byte $fb, $80, K_RIGHT     ; X
    .byte $fd, $10, K_LEFT      ; Z
    .byte $bf, $04, K_UP        ; ;
    .byte $bf, $80, K_DOWN      ; /
    .byte $fd, $04, K_TERM      ; A
    .byte $ef, $04, K_JET       ; J
    .byte $fe, $02, K_JUMP      ; RETURN
    .byte $bf, $20, K_FIRE      ; =
    .byte $7f, $80, K_ESC       ; RUN/STOP
    .byte $fe, $20, K_F1        ; F3: sound on
    .byte $fe, $10, K_F0        ; F1: sound off
    .byte $df, $02, K_PAUSE     ; P
    .byte $fe, $01, K_PAUSE     ; DEL
    .byte $fb, $04, K_MINE      ; D
    .byte $7f, $04, K_TAB       ; CTRL
    .byte $ef, $40, K_O         ; O
    .byte $7f, $10, K_SPACE     ; SPACE
    .byte $fd, $20, K_S         ; S
    .byte $f7, $10, K_B         ; B
    .byte $ef, $10, K_M         ; M
KEYS = 20

keybit:     .byte $01, $02, $04, $08, $10, $20, $40, $80

; set_key: key number A is held
set_key:
    sec
    sbc #1
    pha
    lsr
    lsr
    lsr
    tax
    pla
    and #7
    tay
    lda keybit,y
    ora keys,x
    sta keys,x
    rts

; is_held: key number A held? Z clear if so
is_held:
    sec
    sbc #1
    pha
    lsr
    lsr
    lsr
    tax
    pla
    and #7
    tay
    lda keybit,y
    and keys,x
    rts

read_keys:
    lda #0
    sta keys
    sta keys + 1
    sta keys + 2
    ldx #0
@k: lda keytab,x
    sta $dc00
    lda $dc01
    and keytab + 1,x
    bne @no
    stx zx
    lda keytab + 2,x
    jsr set_key
    ldx zx
@no:
    inx
    inx
    inx
    cpx #KEYS * 3
    bne @k
    lda #$ff
    sta $dc00
    lda $dc00
    sta zv
    and #$04
    bne :+
    lda #K_LEFT
    jsr set_key
:   lda zv
    and #$08
    bne :+
    lda #K_RIGHT
    jsr set_key
:   lda zv
    and #$01
    bne :+
    lda #K_UP
    jsr set_key
:   lda zv
    and #$02
    bne :+
    lda #K_DOWN
    jsr set_key
:   lda zv
    and #$10
    bne :+
    lda #K_JUMP
    jsr set_key
:   ; the order of pressing: drop the released
    ldx #0
@d: lda heldord,x
    beq @dn
    stx zx
    jsr is_held
    ldx zx
    bne @dn
    lda #0
    sta heldord,x
@dn:
    inx
    cpx #4
    bne @d
    ; compact
    ldx #0
    ldy #0
@c: lda heldord,x
    beq @cn
    sta zv
    lda #0
    sta heldord,x
    lda zv
    sta heldord,y
    iny
@cn:
    inx
    cpx #4
    bne @c
    ; new ones
    lda #1
    sta zs
@n: lda zs
    jsr is_held
    beq @nn
    ldx #0
@f: lda heldord,x
    cmp zs
    beq @nn
    inx
    cpx #4
    bne @f
    ldx #0
@e: lda heldord,x
    beq @add
    inx
    cpx #4
    bne @e
    jmp @nn
@add:
    lda zs
    sta heldord,x
@nn:
    inc zs
    lda zs
    cmp #KEYS + 1
    bne @n
    ; key2 = the first, key1 = the last
    lda heldord
    sta key2
    lda #0
    sta key1
    ldx #3
@l: lda heldord,x
    bne @got
    dex
    bpl @l
    rts
@got:
    sta key1
    rts
