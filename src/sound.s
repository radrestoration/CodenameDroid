; sound.s: the BBC's SOUND (OSWORD 7) on the SID.
;
; The game queues notes with OSWORD 7 (channel, amplitude, pitch, duration), four deep per channel, on the BBC's
; channels 0 (noise) and 1-3 (tones), and asks OSBYTE 128 how much room a queue has to pace its tune. The queues and
; the timing are done here the way the OS does them; the sound is made by the SID:
;   BBC channel 1, 2  ->  SID voice 1, 2        BBC channel 3 and 0 (noise)  ->  SID voice 3 (the later note wins)
; Amplitude: a volume (0 to -15) is the SID's sustain level; an envelope number (1-4) is that envelope's
; attack/decay/sustain/release (tools/make_sound_tables.py turns the game's four envelopes into SID bytes) and its
; pitch changes, which are stepped here every 1/100 s. Durations are in 1/20 s; the interrupt (50 or 60 Hz) runs the
; 100 Hz clock from an accumulator.
; Not done: the BBC's sync and hold flags (the game does not use them), periodic noise (the SID has none).

SND         = $ed00             ; variables (RAM nothing else uses; the cell tables end below)
q_amp       = SND               ; 16: queue entries, channel * 4 + slot. Amplitude: bit 7 = envelope (low 2 bits - 1),
q_pit       = SND + 16          ;     else the volume 0-15
q_dur       = SND + 32          ; 16: duration (1/20 s), never 0
qhead       = SND + 48          ; 4: per channel
qcnt        = SND + 52
cact        = SND + 56          ; 1 = a note is playing
cdur        = SND + 60          ; 1/20 s left
csub        = SND + 64          ; 1/100 s ticks of the current 1/20 s
cpit        = SND + 68
cenv        = SND + 72          ; the envelope's offset in sound_env
cfl         = SND + 76          ; bit 1: the pitch is sliding
csec        = SND + 80          ; slide section 0-2
cstep       = SND + 84          ; steps left in the section
snd_acc     = SND + 88
snd_hz      = SND + 89
snd_off     = SND + 90          ; 0 for PAL, 96 for NTSC (offset in sound_f4)
snd_flo     = SND + 91
snd_fhi     = SND + 92
snd_sx      = SND + 93
snd_t       = SND + 94
snd_idx     = SND + 95
snd_blk     = SND + 96          ; 8: the OSWORD block
SND_END     = SND + 104

.segment "SOUNDC"
snd_voff:   .byte 14, 0, 7, 14  ; channel -> voice register offset
snd_wave:   .byte $80, $40, $40, $40
snd_nhi:    .byte $68, $34, $1a ; the noise rates (high bytes; the BBC's three fixed rates)

snd_init:
    lda #0
    ldx #SND_END - SND - 1
@z: sta SND,x
    dex
    bpl @z
    ldx #50
    lda c64_pal
    bne @pal
    ldx #60
    lda #96
    sta snd_off
@pal:
    stx snd_hz
    ldx #14
@v: lda #0
    sta $d400,x
    sta $d401,x
    sta $d402,x
    sta $d404,x
    sta $d405,x
    sta $d406,x
    lda #$08
    sta $d403,x                 ; pulse width $0800: a square wave, as the BBC's
    txa
    sec
    sbc #7
    tax
    bpl @v
    lda #$0f
    sta $d418
    rts

; snd_frame: once per frame, from the interrupt
snd_frame:
    ldx #$0f
    lda os_sound_suppression    ; the OS silences everything while this is set
    beq @on
    ldx #0
@on:
    stx $d418
    lda snd_acc
    clc
    adc #100
    sta snd_acc
@loop:
    lda snd_acc
    sec
    sbc snd_hz
    bcc @done
    sta snd_acc
    jsr snd_tick
    jmp @loop
@done:
    rts

snd_tick:
    ldx #3
@ch:
    jsr snd_slide               ; (the envelope's pitch changes go on in the release, after the note's duration)
    lda cact,x
    beq @idle
    inc csub,x
    lda csub,x
    cmp #5
    bcc @next
    lda #0
    sta csub,x
    dec cdur,x
    bne @next
    jsr snd_stop
@idle:
    lda qcnt,x
    beq @next
    jsr snd_start
@next:
    dex
    bpl @ch
    rts

snd_stop:                       ; X = channel: end the note (the release phase starts)
    lda #0
    sta cact,x
    ldy snd_voff,x
    lda snd_wave,x
    sta $d404,y
    rts

snd_flush:                      ; X = channel
    lda #0
    sta cfl,x
    sta qcnt,x
    sta qhead,x
    lda cact,x
    beq @r
    jsr snd_stop
@r: rts

snd_flushall:
    ldx #3
@l: jsr snd_flush
    dex
    bpl @l
    rts

; snd_start: X = channel, with a note waiting: take it from the queue and start it
snd_start:
    txa
    asl
    asl
    ora qhead,x
    tay
    lda qhead,x
    clc
    adc #1
    and #3
    sta qhead,x
    dec qcnt,x
    lda q_pit,y
    sta cpit,x
    lda q_dur,y
    sta cdur,x
    lda q_amp,y
    sta snd_t
    lda #0
    sta csub,x
    sta cfl,x
    cpx #0                      ; the noise and channel 3 share a voice: the new note takes it
    bne @n0
    sta cact + 3
    sta cfl + 3
@n0:
    cpx #3
    bne @n3
    sta cact + 0
    sta cfl + 0
@n3:
    ldy snd_voff,x
    lda snd_wave,x
    sta $d404,y                 ; gate off, so the note starts again
    lda snd_t
    bmi @env
    asl
    asl
    asl
    asl
    sta $d406,y                 ; the volume: sustain level, nothing else
    lda #0
    sta $d405,y
    beq @freq
@env:
    and #3
    asl
    asl
    asl
    asl
    sta cenv,x
    stx snd_sx
    tax
    lda sound_env,x
    sta $d405,y
    lda sound_env + 1,x
    sta $d406,y
    lda sound_env + 6,x         ; first slide section's steps
    sta snd_t
    lda sound_env + 2,x
    and #2
    ldx snd_sx
    sta cfl,x
    lda snd_t
    sta cstep,x
    lda #0
    sta csec,x
@freq:
    jsr snd_setfreq             ; (leaves X = channel, Y = voice offset)
    lda snd_wave,x
    ora #1
    sta $d404,y                 ; gate on
    lda #1
    sta cact,x
    rts

; snd_slide: X = channel, one 1/100 s step of the envelope's pitch change
snd_slide:
    lda cfl,x
    and #2
    beq @r
    lda cenv,x
    clc
    adc csec,x
    tay
    lda cstep,x
    bne @step
    lda csec,x                  ; the section is done: the next one, or stop
    clc
    adc #1
    cmp #3
    bcs @end
    sta csec,x
    lda sound_env + 7,y         ; (its steps: PN1 + 1 + sec)
    sta cstep,x
@r: rts
@end:
    lda #0
    sta cfl,x
    rts
@step:
    dec cstep,x
    lda sound_env + 3,y
    sta snd_t
    clc
    adc cpit,x
    bit snd_t
    bmi @neg
    bcc @ok
    lda #$ff
    bne @ok
@neg:
    bcs @ok
    lda #0
@ok:
    sta cpit,x

; snd_setfreq: X = channel (kept): set its voice's frequency for pitch cpit (4 units a semitone, 89 = A 440)
snd_setfreq:
    stx snd_sx
    lda cpit,x
    cpx #0
    bne @calc
    and #3                      ; noise: 0-2 a rate, 3 = the rate of channel 1's pitch
    cmp #3
    bne @fixed
    lda cpit + 1
@calc:
    ldx #0                      ; A mod 48 = the note, X = the octave
@div:
    cmp #48
    bcc @dd
    sbc #48
    inx
    bne @div
@dd:
    clc
    adc snd_off
    tay
    lda sound_f4,y
    sta snd_flo
    lda sound_f4 + 48,y
    sta snd_fhi
    cpx #4                      ; the table is octave 4
    beq @write
    bcc @shr
    asl snd_flo                 ; octave 5: up one, to the top of the range at most
    rol snd_fhi
    bcc @write
    lda #$ff
    sta snd_flo
    sta snd_fhi
    bne @write
@shr:
    lsr snd_fhi
    ror snd_flo
    inx
    cpx #4
    bcc @shr
    bcs @write
@fixed:
    tax
    lda snd_nhi,x
    sta snd_fhi
    lda #0
    sta snd_flo
@write:
    ldx snd_sx
    ldy snd_voff,x
    lda snd_flo
    sta $d400,y
    lda snd_fhi
    sta $d401,y
    rts

; snd_osword: OSWORD with A = 7, X/Y = the sound block: channel (2), amplitude (2), pitch (2), duration (2)
snd_osword:
    cmp #7
    beq @go
    rts
@go:
    php
    sei
    pha
    txa
    pha
    tya
    pha
    stx @blk + 1
    sty @blk + 2
    ldy #7
@blk:
    lda $ffff,y
    sta snd_blk,y
    dey
    bpl @blk
    lda snd_blk
    and #3
    tax
    lda snd_blk
    and #$10                    ; flush this channel first
    beq @nf
    jsr snd_flush
@nf:
    lda qcnt,x
    cmp #4
    bcs @done                   ; (the OS would wait for room)
    lda snd_blk + 3
    beq @henv
    lda snd_blk + 2             ; a volume, 0 to -15 (loudest): level 0-15
    eor #$ff
    clc
    adc #1
    and #$0f
    bpl @put
@henv:
    lda snd_blk + 2             ; an envelope number
    beq @put
    cmp #5
    bcs @sil
    clc
    adc #$7f                    ; $80 | (number - 1)
    bne @put
@sil:
    lda #0
@put:
    sta snd_t
    lda qhead,x
    clc
    adc qcnt,x
    and #3
    sta snd_idx
    txa
    asl
    asl
    ora snd_idx
    tay
    lda snd_t
    sta q_amp,y
    lda snd_blk + 4
    sta q_pit,y
    lda snd_blk + 6
    bne @d
    lda #1
@d: sta q_dur,y
    inc qcnt,x
@done:
    pla
    tay
    pla
    tax
    pla
    plp
    rts
