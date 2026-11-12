; ---- the title screen: the BBC's own, as characters (made by tools/make_data.py from the BBC game run to its title loop),
; with the player walking on the spot and firing now and then, the tune, and the keys: SPACE to start, J to jump to the saved
; place, F1 and F3 for the sound.

.segment "BSS"
title_jump: .res 1
tune_mode:  .res 1
tf:         .res 1
ta:         .res 1
saved_score: .res 8
saved_carried: .res 16
saved_suit: .res 1
saved_blaster: .res 1
saved_jp:   .res 1
saved_lives: .res 1
saved_maxjump: .res 1
saved_total: .res 1
.segment "CODE"

zero14:     .res 14

rows_clear:
    lda rows_page
    sta p2 + 1
    lda #0
    sta p2
    ldx #32
:   ldy #39
    lda #0
:   sta (p2),y
    dey
    bpl :-
    inc p2 + 1
    dex
    bne :--
    rts

title_screen:
    jsr screen_off
    jsr snd_flushall
    jsr intern_reset
    lda #TITLE_CHARS
    sta nchars
    ; the characters
    lda #<(title_chars + 8)
    sta p3
    lda #>(title_chars + 8)
    sta p3 + 1
    lda #1
    sta zr
@c: ldy #7
:   lda (p3),y
    sta cb,y
    dey
    bpl :-
    lda zr
    jsr set_char
    lda p3
    clc
    adc #8
    sta p3
    bcc :+
    inc p3 + 1
:   inc zr
    lda zr
    cmp #TITLE_CHARS
    bne @c
    ; the screen: rows 4 - 28, the 40 columns of the wide arrangement
    jsr rows_clear
    lda #<title_map
    sta p4
    lda #>title_map
    sta p4 + 1
    lda #4
    sta zr                      ; row
@r: lda #0
    sta p2
    lda zr
    clc
    adc rows_page
    sta p2 + 1
    ldy #39
:   lda (p4),y
    sta (p2),y
    dey
    bpl :-
    lda p4
    clc
    adc #40
    sta p4
    bcc :+
    inc p4 + 1
:   inc zr
    lda zr
    cmp #29
    bne @r
    lda #4
    sta scr_col0
    jsr scr_reset_text
    lda deepest
    beq @nojump
    PRINT text_jump, $0f
@nojump:
    jsr plot_music_state
    ; the view: window 0, rows 4 - 28
    lda #0
    sta cur_w
    sta mat_w
    sta mat_w + 1
    sta cur_buf
    sta spx_l
    sta spx_h
    sta t_w
    sta p_msb
    lda #4
    sta cur_cam
    sta mat_c
    sta mat_c + 1
    lda #>MAT_A
    jsr draw_full
    lda #>MAT_B
    jsr draw_full
    lda #D018_A
    sta p_d018
    lda #$10
    sta p_d016
    ; the player
    lda #18
    sta px
    sta pc
    lda #136
    sta py
    lda #0
    sta pdir
    sta pstance
    sta pframe
    sta skel_show
    sta carried + 2
    sta obst_pix
    sta title_jump
    sta pjf
    sta ta
    jsr snap_player
    lda #$25
    sta blaster_energy
    jsr init_mines_blasters
    ; the tune
    lda #$ff
    sta tune_ptr
    lda #3
    sta tune_ptr + 1
    lda #0
    sta tune_mode
    lda #1
    sta tune_playing
    lda #1
    sta title_on
    jsr screen_on
@loop:
    jsr frame_wait
    jsr read_keys
    ; the BBC's title loop is two vertical retraces long: the blasters move each time, the player's frame and the firing every
    ; other (12 units of 6 a PAL frame, 5 an NTSC one)
    lda ta
    clc
    adc add
    sta ta
    cmp #12
    bcc @nof
    sbc #12
    sta ta
    inc tf
    jsr update_blasters
    lda tf
    and #1
    bne @nof
    jsr plot_facing
    jsr rnd
    and #7
    bne @nof
    jsr fire_blaster
@nof:
    jsr update_tune
    lda #K_F0
    jsr is_held
    beq @n0
    lda sound_off
    bne @n0
    lda #1
    sta sound_off
    jsr plot_music_state
@n0:
    lda #K_F1
    jsr is_held
    beq @n1
    lda sound_off
    beq @n1
    lda #0
    sta sound_off
    jsr plot_music_state
@n1:
    jsr make_sprites
    lda #1
    sta ready
    lda deepest
    beq @nj
    lda #K_JET
    jsr is_held
    beq @nj
    lda #1
    sta title_jump
    jmp @done
@nj:
    lda #K_SPACE
    jsr is_held
    bne @done
    jmp @loop
@done:
    lda #0
    sta title_on
    sta p_en
    jsr snd_flushall
    jsr init_mines_blasters
    rts

; plot_music_state: the notes if the sound is on
plot_music_state:
    lda #<spr_notes
    ldx #>spr_notes
    ldy sound_off
    beq :+
    lda #<zero14
    ldx #>zero14
:   sta p3
    stx p3 + 1
    lda #$1a
    sta text_x
    lda #2
    ldx #7
    ldy #$a9
    jmp blit_at

; ---- the saved game, kept at the lifts of the shrine and the quarters (consider_saving_position)
save_game:
    ldx #7
:   lda score,x
    sta saved_score,x
    dex
    bpl :-
    ldx #15
:   lda carried,x
    sta saved_carried,x
    dex
    bpl :-
    lda suit_energy
    sta saved_suit
    lda blaster_energy
    sta saved_blaster
    lda jp_energy
    sta saved_jp
    lda lives
    sta saved_lives
    lda maxjump
    sta saved_maxjump
    lda total_objs
    sta saved_total
    rts

; jump_to_saved: after new_game: the saved state and the lift of the saved place
jump_to_saved:
    jsr set_surface_tiles
    ldx #7
:   lda saved_score,x
    sta score,x
    dex
    bpl :-
    ldx #15
:   lda saved_carried,x
    sta carried,x
    dex
    bpl :-
    lda saved_suit
    sta suit_energy
    lda saved_blaster
    sta blaster_energy
    lda saved_jp
    sta jp_energy
    lda saved_lives
    sta lives
    lda saved_maxjump
    sta maxjump
    lda saved_total
    sta total_objs
    lda deepest
    cmp #1
    bne @crews
    ; the shrine: its right lift, with a wall above it
    lda #$37
    sta LTILES + 3 * 256 + $f8
    lda #$02
    sta LTILES + 3 * 256 + $f9
    lda #$31
    sta LTILES + 3 * 256 + $fa
    lda #$f8
    sta init_px
    lda #3
    jmp set_level
@crews:
    lda #$3a
    sta LTILES + 6 * 256 + 4
    lda #$02
    sta LTILES + 6 * 256 + 5
    lda #$31
    sta LTILES + 6 * 256 + 6
    lda #4
    sta init_px
    lda #6
    jmp set_level
