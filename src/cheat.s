; ---- the test build (make CHEAT=1): keys 1 - 9, 0, Q, W go to levels 1 - 12 (at the right lift), E fills the energy and the
; pass cards and cells, R gives the microfilm, the key and the spanner, T the jet pack

.segment "BSS"
cheat_last: .res 1
.segment "CODE"

; (column select, row mask, level or $f0 + action)
cheat_tab:
    .byte $7f, $01, 0           ; 1
    .byte $7f, $08, 1           ; 2
    .byte $fd, $01, 2           ; 3
    .byte $fd, $08, 3           ; 4
    .byte $fb, $01, 4           ; 5
    .byte $fb, $08, 5           ; 6
    .byte $f7, $01, 6           ; 7
    .byte $f7, $08, 7           ; 8
    .byte $ef, $01, 8           ; 9
    .byte $ef, $08, 9           ; 0
    .byte $7f, $40, 10          ; Q
    .byte $fd, $02, 11          ; W
    .byte $fd, $40, $f0         ; E
    .byte $fb, $02, $f1         ; R
    .byte $fb, $40, $f2         ; T
CHEATS = 15

cheat_keys:
    ldx #0
@k: lda cheat_tab,x
    sta $dc00
    lda $dc01
    and cheat_tab + 1,x
    beq @hit
    inx
    inx
    inx
    cpx #CHEATS * 3
    bne @k
    lda #$ff
    sta $dc00
    lda #$ff
    sta cheat_last
    rts
@hit:
    lda #$ff
    sta $dc00
    lda cheat_tab + 2,x
    cmp cheat_last
    bne :+
    rts
:   sta cheat_last
    cmp #$f0
    bcs @action
    ; a level
    pha
    lda #$f8
    sta init_px
    lda #0
    sta arrive_mode
    pla
    jsr set_level
    rts
@action:
    cmp #$f0
    bne @n1
    lda #$25
    sta suit_energy
    sta blaster_energy
    lda #3
    sta lives
    lda #9
    sta carried
    sta carried + 1
    rts
@n1:
    cmp #$f1
    bne @n2
    lda #1
    sta carried + $c
    sta carried + 4
    lda #2
    sta carried + 9
    rts
@n2:
    lda #1
    sta carried + 2
    lda #$ff
    sta jp_energy
    rts
