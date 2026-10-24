; The disc release's startup: the last page of CDroid4 (load &1100, exec &6e00).
; Not part of the listing, which is the tape release; written from the bytes
; on Disc032 and checked against them by tools/check_build.py.
;
; CDroid4 is the game (&1100-&57ff) followed by the data blocks, which this
; code moves to where the game uses them. The block at &5800 is already in
; place; the others are staged just before this code:
;     &6000-&6cff -> &0400-&10ff     &6d00-&6d3f -> &03a0     &6d40-&6d7f -> &0180
;     &6d80-&6d9f -> &0380           &6da0-&6dff -> &0300
; The tape release's entry code (tape_entry.s) does the same job from a
; different file layout, and also sets R13/R6/R7 and the sound flag, which
; here are left to MODE 5.

.import __D2_0400_LOAD__, __D2_03A0_LOAD__, __D2_0180_LOAD__
.import __D2_0380_LOAD__, __D2_0300_LOAD__

.segment "DISC_ENTRY"

disc_entry:
    lda #$13                         ; VDU 19,2,6,0,0,0: set colour 2 to cyan
    jsr OSWRCH
    lda #$02
    jsr OSWRCH
    lda #$06
    jsr OSWRCH
    lda #$00
    jsr OSWRCH
    jsr OSWRCH
    jsr OSWRCH
    lda #$05                         ; Set addressable latch B5 to 0
    sta $fe40                        ; System VIA port B input/output register
    lda #$0c                         ; Set addressable latch B4 to 1, i.e. screen scrolls
    sta $fe40
    ldx #$00
disc_write_video_registers_loop:
    lda disc_video_register_data,x
    sta $fe00                        ; video register number
    lda disc_video_register_data+1,x
    sta $fe01                        ; video register value
    inx
    inx
    cpx #$08
    bne disc_write_video_registers_loop
    lda #$8c                         ; Select Tape FS
    jsr OSBYTE
    ldy #$00                         ; Move &6000-&6cff to &0400-&10ff
    tya
    sta $70                          ; target_address_low
    sta $72                          ; source_address_low
    lda #$04
    sta $71                          ; target_address_high
    lda #>__D2_0400_LOAD__
    sta $73                          ; source_address_high
disc_move_0400_loop:
    lda ($72),y                      ; source_address
    sta ($70),y                      ; target_address
    iny
    bne disc_move_0400_loop
    inc $73
    inc $71
    lda $71
    cmp #$11
    bne disc_move_0400_loop
    ldx #$00
disc_move_03a0_loop:
    lda __D2_03A0_LOAD__,x
    sta $03a0,x
    inx
    cpx #$40
    bne disc_move_03a0_loop
    ldx #$00
disc_move_0180_loop:
    lda __D2_0180_LOAD__,x
    sta $0180,x
    inx
    cpx #$40
    bne disc_move_0180_loop
    ldx #$00
disc_move_0380_loop:
    lda __D2_0380_LOAD__,x
    sta $0380,x
    inx
    cpx #$20
    bne disc_move_0380_loop
    lda #$c8                         ; Read/Write BREAK/ESCAPE effect
    ldx #$03                         ; Clear memory on next RESET
    ldy #$00
    jsr OSBYTE
    lda #$0b                         ; Set auto-repeat delay
    ldx #$00
    ldy #$00
    jsr OSBYTE
    ldx #$00
    txa
disc_wipe_0100_loop:
    sta $0100,x                      ; Wipe &0100 - &017f
    inx
    cpx #$80
    bne disc_wipe_0100_loop
    lda #$00
    sta level
    sta level_sprite_base
    lda #$00
    tax
disc_move_0300_loop:
    lda __D2_0300_LOAD__,x
    sta $0300,x
    inx
    cpx #$60
    bne disc_move_0300_loop
    lda #$d4
    sta $fe62                        ; User VIA data direction register B
    ldx #$ff
    txs
    lda #$08
    sta $fe00                        ; video register number
    lda #$00
    sta $fe01                        ; video register value
    jmp new_game

disc_video_register_data:
    .byte $01,$20                    ; R1: Number of characters per line
    .byte $0a,$20                    ; R10: Cursor start register
    .byte $02,$2e                    ; R2: Horizontal sync position register
    .byte $0c,$0c                    ; R12: Displayed screen start address register (high)   # Screen starts at &6000

; The rest of the page, as on the disc: what looks like the tail of the tape
; release's register table, then &01s.
    .byte $20,$02,$2e,$0c,$0c
    .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
    .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
    .byte $01,$01,$01,$01,$01,$01,$01,$01,$01
