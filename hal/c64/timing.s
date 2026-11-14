; The C64's timing and screen blanking. The raster interrupt (irq in game.s) counts `tick` once a frame.
; frame_wait: until the next frame; wait_frames: A frames; screen_off / screen_on: blank the display while it is rebuilt.

frame_wait:
    lda tick
:   cmp tick
    beq :-
    rts

screen_off:
    lda #$0b
    sta $d011
    rts
screen_on:
    lda #$1b
    sta $d011
    rts

; wait_frames: A frames
wait_frames:
    clc
    adc tick
    sta zv
:   lda tick
    cmp zv
    bne :-
    rts
