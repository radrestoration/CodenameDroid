; ---- blasters: six slots, 0 and 1 the player's, 2 - 5 the enemies'. A blaster moves a cell at a time (twice in a step) and stops
; at the first non-blank byte it meets: an enemy's characters, the player's picture, or the level.

.segment "BSS"
ub_slot:    .res 1
bt_slot:    .res 1
.segment "CODE"

check_player_blasters:
remove_colliding_blasters:
    rts

fire_blaster:
    ldx #0
    lda bl_ttl
    cmp #$ff
    beq @found
    ldx #1
    lda bl_ttl + 1
    cmp #$ff
    beq @found
    rts
@found:
    lda carried + 2
    bne @skip
    lda blaster_energy
    bne @has
    rts
@has:
    dec blaster_energy
@skip:
    lda pstance
    cmp #2
    bne :+
    rts
:   lda #$0e
    clc
    adc pdir
    sta bl_ttl,x
    lda pdir
    sta bl_dir,x
    bne @left
    lda pc
    clc
    adc #3
    jmp @col
@left:
    lda pc
    sec
    sbc #1
@col:
    sta bl_c,x
    lda py
    clc
    adc #13
    ldy pstance
    cpy #1
    bne :+
    clc
    adc #5
:   sta bl_l,x
    lda title_on
    bne :+
    stx ub_slot
    jsr sfx_player_fire
    ldx ub_slot
:   jmp blaster_test

update_blasters:
    ldx #0
@l: lda bl_ttl,x
    cmp #$ff
    bcs @next
    lda bl_dir,x
    bne @left
    inc bl_c,x
    beq @rm
    jmp @moved
@left:
    lda bl_c,x
    beq @rm
    dec bl_c,x
@moved:
    dec bl_ttl,x
    beq @rm
    lda bl_c,x
    sec
    sbc t_w
    cmp #38
    bcs @rm
    stx ub_slot
    jsr blaster_test
    ldx ub_slot
    jmp @next
@rm:
    lda #$ff
    sta bl_ttl,x
@next:
    inx
    cpx #6
    bne @l
    rts

; blaster_test: slot X: what is in its cell (and the one below)?
blaster_test:
    stx bt_slot
    lda bl_c,x
    sta sa_c
    lda bl_l,x
    sta sa_l
    jsr rdb
    bne @hit
    inc sa_l
    jsr rdb
    bne @hit
    ; the player (not for the player's own)
    ldx bt_slot
    cpx #2
    bcc @done
    lda pstance
    cmp #$f0
    beq @done
    lda bl_c,x
    sec
    sbc pc
    sta zs
    lda bl_l,x
    sec
    sbc py
    tay
    lda zs
    jsr player_byte
    bne @hitplayer
    ldx bt_slot
    lda bl_c,x
    sec
    sbc pc
    sta zs
    lda bl_l,x
    sec
    sbc py
    tay
    iny
    lda zs
    jsr player_byte
    bne @hitplayer
@done:
    ldx bt_slot
    rts
@hit:
    ; an enemy's? the cell's character is in the pool
    lda sa_l
    lsr
    lsr
    lsr
    tay
    ldx sa_c
    jsr get_cell
    sec
    sbc pool_base
    bcc @gone
    ldx #0
@slot:
    cmp #12
    bcc @slot_found
    sbc #12
    inx
    cpx pool_groups
    bcs @gone
    jmp @slot
@slot_found:
    lda pool_owner,x
    cmp #$ff
    beq @gone
    tax
    jsr damage_enemy
@gone:
    ldx bt_slot
    lda #$ff
    sta bl_ttl,x
    rts
@hitplayer:
    dec suit_energy
    dec suit_energy
    lda #2
    jsr play_sound_for_damage
    ldx bt_slot
    lda #$ff
    sta bl_ttl,x
    rts
