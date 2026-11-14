; One frame of the game: keys, the BBC-rate game steps, the camera, the screen matrix and the sprites, staged for the display.
; (BORDER is the platform's timing aid.)

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
    jsr snap_player
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

