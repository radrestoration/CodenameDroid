; Apple IIgs boot-block experiment: show 16 grey bars in Super Hi-Res, then stop.
; Boot contract (UNVERIFIED on hardware): block 0 at $0800, first byte $01, entered at $0801 in
; emulation mode. SHR layout verified against GSplus video.c: bank $E1, pixels $2000 (160 bytes/line,
; 200 lines), SCB $9D00+line, palette n at $9E00+n*$20. NEWVIDEO ($C029) bit 7 = SHR, bit 6 = linear;
; bit 0 must not be changed, so it is read-modify-write.
.p816
.segment "CODE"
        .byte   $01             ; ProDOS boot ID
start:  sei
        clc
        xce                     ; native mode
        rep     #$30
        .a16
        .i16
        ldx     #0
        lda     #0
@pal:   sta     $e19e00,x       ; palette 0, entry n = grey n (xRGB = n*$111)
        clc
        adc     #$0111
        inx
        inx
        cpx     #32
        bne     @pal
        sep     #$20
        .a8
        lda     #0
        ldx     #0
@scb:   sta     $e19d00,x       ; every line: palette 0, 320 mode
        inx
        cpx     #200
        bne     @scb
        ldx     #0              ; line 0: 16 bars of 10 bytes
        lda     #0
@bar:   ldy     #10
@byte:  sta     $e12000,x
        inx
        dey
        bne     @byte
        clc
        adc     #$11
        cpx     #160
        bne     @bar
        rep     #$20
        .a16
        ldx     #$2000          ; copy forward over itself: repeats the 160-byte line
        ldy     #$20a0
        lda     #31840-1
        mvn     $e10000,$e10000
        sep     #$20
        .a8
        lda     $e0c029
        ora     #$c0
        sta     $e0c029         ; SHR on
@halt:  bra     @halt
