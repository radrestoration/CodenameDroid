; The C64's keyboard (and joystick port 2): hal_scan_keys calls set_key (key number in A) for every key held.

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


; hal_scan_keys
hal_scan_keys:
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
:   rts
