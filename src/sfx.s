; ---- sound: the BBC's SOUND calls (OSWORD 7) on the SID driver of the C64 port (src/sound.s)

.segment "BSS"
sblk:       .res 8
tune_ptr:   .res 2              ; the BBC's tune_address
tune_playing: .res 1
.segment "CODE"

.macro SOUND chan, alo, ahi, pitch, dur
    lda #chan
    sta sblk
    lda #0
    sta sblk + 1
    lda #alo
    sta sblk + 2
    lda #ahi
    sta sblk + 3
    lda #pitch
    sta sblk + 4
    lda #0
    sta sblk + 5
    lda #dur
    sta sblk + 6
    lda #0
    sta sblk + 7
    ldx #<sblk
    ldy #>sblk
    lda #7
    jsr snd_osword
.endmacro

sfx_pickup:
    SOUND $12, 4, 0, $c8, 2
    rts
sfx_lift:
    SOUND $12, $f4, $ff, 0, $0d
    rts
sfx_chime:
    SOUND $12, 4, 0, $d2, 4
    rts
sfx_warning:
    SOUND $12, 4, 0, $19, 4
    rts
sfx_player_fire:
    SOUND 3, 2, 0, $65, 1
    rts
sfx_enemy_fire:
    SOUND $12, 2, 0, $8c, 1
    rts

; play_sound_for_damage: A the duration of the noise
play_sound_for_damage:
    sta sblk + 6
    lda #$10
    sta sblk
    lda #0
    sta sblk + 1
    lda #$f1
    sta sblk + 2
    lda #$ff
    sta sblk + 3
    lda #7
    sta sblk + 4
    lda #0
    sta sblk + 5
    sta sblk + 7
    ldx #<sblk
    ldy #>sblk
    lda #7
    jsr snd_osword
    SOUND $11, 3, 0, $b4, 8
    rts

; ---- the tune of the game over screen (the BBC's update_tune)
tune_off = tune_data - $0400

start_game_over_tune:
    lda #1
    sta tune_mode
    lda #$7f
    sta tune_ptr
    lda #$05
    sta tune_ptr + 1
    lda #0
    sta tune_playing
    rts

; update_tune: when the first channel's queue has room, the next melody and percussion bytes
update_tune:
    lda tune_playing
    bne :+
    rts
:   lda qcnt
    cmp #4
    bcc :+
    rts
:   jsr tune_next
    ldy #0
    lda (p1),y
    cmp #$ff
    bne @note
    SOUND 1, 0, 0, 0, 3
    SOUND 2, 0, 0, 0, 3
    jmp @perc
@note:
    sec
    sbc #$22
    sta zv
    lda zv
    sta sblk + 4
    lda #1
    sta sblk
    lda #0
    sta sblk + 1
    lda #1
    sta sblk + 2
    lda #0
    sta sblk + 3
    sta sblk + 5
    sta sblk + 7
    lda #3
    sta sblk + 6
    ldx #<sblk
    ldy #>sblk
    lda #7
    jsr snd_osword
    inc zv
    lda zv
    sta sblk + 4
    lda #2
    sta sblk
    ldx #<sblk
    ldy #>sblk
    lda #7
    jsr snd_osword
@perc:
    jsr tune_next
    ldy #0
    lda (p1),y
    beq @silent
    sta zv
    lda #0
    sta sblk
    sta sblk + 1
    sta sblk + 3
    sta sblk + 5
    sta sblk + 7
    lda #4
    sta sblk + 2
    lda zv
    sta sblk + 4
    lda #3
    sta sblk + 6
    ldx #<sblk
    ldy #>sblk
    lda #7
    jsr snd_osword
    jmp @end
@silent:
    SOUND 0, 0, 0, 0, 3
@end:
    ; the end of the game over tune: $05df: it ends (the screen stops updating)
    lda tune_mode
    bne @over
    ; the title tune loops: from $051f back to $045f
    lda tune_ptr + 1
    cmp #5
    bcc @r
    lda tune_ptr
    cmp #$1f
    bne @r
    lda #$5f
    sta tune_ptr
    lda #4
    sta tune_ptr + 1
    rts
@over:
    lda tune_ptr
    cmp #$df
    bne @r
    lda #0
    sta tune_playing
@r: rts

; tune_next: advance tune_ptr and point p1 at that byte of tune_data
tune_next:
    inc tune_ptr
    bne :+
    inc tune_ptr + 1
:   lda tune_ptr
    clc
    adc #<tune_off
    sta p1
    lda tune_ptr + 1
    adc #>tune_off
    sta p1 + 1
    rts
