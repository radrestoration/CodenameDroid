; ---- keyboard and joystick (port 2): the keys held as bits, and the order they were pressed in (the BBC game looks at the most
; recently pressed key and the first pressed key)

.segment "BSS"
heldord:    .res 4
.segment "CODE"

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
    jsr hal_scan_keys
    ; the order of pressing: drop the released
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
