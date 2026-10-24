; Tape release only: DROID2's entry code (exec &7b00). The disc has its own, disc_entry.s.

.segment "D2_7B00"

entry_point_7b00:
    lda #$13                         ; Set colour 2 to cyan
    jsr OSWRCH
    lda #$02
    jsr OSWRCH
    lda #$06                         ; C
    jsr OSWRCH
    lda #$00
    jsr OSWRCH
    jsr OSWRCH
    jsr OSWRCH
    lda #$05                         ; Set addressable latch B5 to 0
    sta $fe40                        ; System VIA port B input/output register
    lda #$0c                         ; Set addressable latch B4 to 1, i.e. screen scrolls from &6000
    sta $fe40                        ; System VIA port B input/output register
    ldx #$00
write_video_registers_loop:
    lda video_register_data,x
    sta $fe00                        ; video register number
    lda $7bf5,x                      ; video_register_data + 1
    sta $fe01                        ; video register value
    inx
    inx
    cpx #$08
    bne write_video_registers_loop
    lda #$0d
    sta $fe00                        ; video register number
    lda #$00
    sta $fe01                        ; video register value
    lda #$06
    sta $fe00                        ; video register number
    lda #$20
    sta $fe01                        ; video register value
    lda #$07
    sta $fe00                        ; video register number
    lda #$22
    sta $fe01                        ; video register value
    lda #$00
    tay
    sta $70                          ; source_address_low
    sta $72                          ; target_address_low
    lda #$04
    sta $73                          ; target_address_high
    lda #$6e
    sta $71                          ; source_address_high
move_6e00_to_7aff_loop:              ; # Move &6e00 - &7aff to &0400 - &10ff
    lda ($70),y                      ; source_address
    sta ($72),y                      ; target_address
    iny
    bne move_6e00_to_7aff_loop
    inc $71                          ; source_address_high
    inc $73                          ; target_address_high
    lda $73                          ; target_address_high
    cmp #$11
    bne move_6e00_to_7aff_loop
    ldy #$00
    tya
    sta $70                          ; target_address_low
    sta $72                          ; source_address_low
    lda #$58
    sta $71                          ; target_address_high
    lda #$65
    sta $73                          ; source_address_high
move_6500_to_6cff_loop:              ; # Move &6500 - &6cff to &5800 - &5fff
    lda ($72),y                      ; source_address
    sta ($70),y                      ; target_address
    iny
    bne move_6500_to_6cff_loop
    inc $73                          ; source_address_high
    inc $71                          ; target_address_high
    lda $71                          ; target_address_high
    cmp #$60
    bne move_6500_to_6cff_loop
    ldx #$00
move_memory_loop:
    lda $6d00,x                      ; Move &6d00 - &6d3f to &03a0 - &03df
    sta objects_type_and_flags,x
    lda $6d40,x                      ; Move &6d40 - &6d7f to &0180 - &01bf
    sta tile_sprite_rope,x
    inx
    cpx #$40
    bne move_memory_loop
    ldx #$00
    ldx #$00
move_memory_two_loop:
    lda $6d80,x                      ; Move &6d80 - &6d9f to &0380 - &039f
    sta object_sprite_spanner,x
    inx
    cpx #$20
    bne move_memory_two_loop
    lda #$0b                         ; Set auto-repeat delay
    ldx #$00
    jsr OSBYTE
    ldx #$00
    stx level
    stx level_sprite_base
    txa
wipe_0100_to_017f_loop:
    sta $0100,x                      ; Wipe &0100 - &017f
    inx
    cpx #$80
    bne wipe_0100_to_017f_loop
    lda #$00
    sta os_sound_suppression         ; Set to zero to permit sound
    tax
move_memory_three_loop:
    lda $6da0,x                      ; Move &6da0 - &6dff to &0300 - &035f
    sta jet_pack_text,x
    inx
    cpx #$60
    bne move_memory_three_loop
    lda #$d4
    sta $fe62                        ; User VIA data direction register B
    ldx #$ff
    txs
    lda #$08
    sta $fe00                        ; video register number
    lda #$00
    sta $fe01                        ; video register value
    jmp new_game

video_register_data:
    .byte $01,$20                    ; ; R1: Number of characters per line
    .byte $0a,$20                    ; ; R10: Cursor start register
    .byte $02,$2e                    ; ; R2: Horizontal sync position register
    .byte $0c,$0c                    ; ; R12: Displayed screen start address register (high)  # Screen starts at &6000

unused_7bfc:
    .byte $6b,$1d,$05,$00
