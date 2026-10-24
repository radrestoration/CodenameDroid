; Tape release only: the loader that ends the DROID file (exec &5800). Not in the disc build.
; It selects the tape filing system and does *RUN Droid2, so it cannot work on disc.

.segment "LOADER"

entry_point_5800:
    lda #$1c                         ; define text window x:(&05, &13), y(&01, &07)
    jsr OSWRCH
    lda #$05
    jsr OSWRCH
    lda #$07
    jsr OSWRCH
    lda #$13
    jsr OSWRCH
    lda #$01
    jsr OSWRCH
    lda #$00
    sta wipe_address_low
    lda #$59
    sta wipe_address_high
wipe_5900_to_7fff_loop:              ; # Wipe &5900 - &7fff
    lda #$00
    sta (wipe_address),y
    iny
    bne wipe_5900_to_7fff_loop
    inc wipe_address_high
    bpl wipe_5900_to_7fff_loop
    lda #$8c                         ; Select Tape FS
    ldx #$00                         ; default speed
    ldy #$00
    jsr OSBYTE
    lda #$c8                         ; Read/Write BREAK/ESCAPE effect
    ldx #$03                         ; Clear memory on next RESET
    ldy #$00
    jsr OSBYTE
    lda #$0c                         ; R12: Displayed screen start address register (high)
    sta $fe00                        ; video register number
    lda #$0b                         ; Set screen start address to &5940
    sta $fe01                        ; video register value
    lda #$0d                         ; R13: Displayed screen start address register (low)
    sta $fe00                        ; video register number
    lda #$28
    sta $fe01                        ; video register value
    lda #$06                         ; R6: Vertical displayed register
    sta $fe00                        ; video register number
    lda #$08
    sta $fe01                        ; video register value
    lda #$07                         ; R7: Vertical sync position
    sta $fe00                        ; video register number
    lda #$1c
    sta $fe01                        ; video register value
    lda #$01
    sta os_sound_suppression         ; Set to non-zero to suppress sound
    ldx #$72                         ; &5872 = run_droid2_command
    ldy #$58
    jmp OSCLI                        ; *RUN Droid2

run_droid2_command:
    .byte $52,$55,$4e,$20,$44,$72,$6f,$69,$64,$32,$0d ; ; "RUN Droid2"

unused_587d:
    .byte $00,$88,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$80,$60,$10,$00
    .byte $00,$00,$00,$f0,$0f,$07,$b0,$70,$f0,$f0,$f0,$00,$c0,$91,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$80,$60
    .byte $10,$00,$00,$f0,$0f,$0f,$f0,$80,$80,$b0,$c0,$00,$00,$88,$cc,$66
    .byte $33,$11,$77,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $80,$60,$10,$f0,$0f,$0f,$f0,$10,$70,$80,$00,$00,$00,$00,$00,$00
    .byte $00,$99,$ee,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$80,$e0,$0f,$0e,$c0,$80,$00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00
