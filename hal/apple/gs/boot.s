; Apple IIgs stage 0 boot block: read the stage 1 loader (blocks 1 - STAGE1_BLOCKS) to STAGE1 and run it.
;
; Contract (confirmed in GSplus with ROM 01 by bars.s, from the hfs-boot source and the Apple IIgs Firmware Reference):
; the firmware loads block 0 at $0800 and enters at $0801 in emulation mode with the slot in the high nibble of X.
; SmartPort dispatch = $Cs00 + [$CsFF] + 3, called in emulation mode with D = 0 and DBR = 0 as
;   JSR dispatch / DFB command / DW parameter list;  carry clear on success. Standard ReadBlock = 1, parameter list
;   {3, unit, buffer (16 bit, bank 0), block (24 bit)}. A failure turns the border red ($C034 low nibble = 1) and stops.
.p816
.include "loader.inc"
.segment "CODE"
        .byte   $01             ; ProDOS boot ID
start:  sei
        txa
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        ora     #$c0            ; the slot's ROM page, $C5 for slot 5
        sta     vec + 1
        sta     $01
        stz     $00             ; ($00) = $Cs00
        ldy     #1              ; the ProDOS/SmartPort signature bytes: $20 xx $00 xx $03 xx $00
        lda     ($00),y
        cmp     #$20
        bne     fail
        ldy     #3
        lda     ($00),y
        bne     fail
        ldy     #5
        lda     ($00),y
        cmp     #$03
        bne     fail
        ldy     #7
        lda     ($00),y
        bne     fail
        ldy     #$ff
        lda     ($00),y         ; the ProDOS entry's low byte; SmartPort's is 3 more
        clc
        adc     #3
        sta     vec
        lda     #STAGE1_BLOCKS
        sta     count
read:
        .byte   $20             ; JSR dispatch, the address patched in above
vec:    .word   $ffff
        .byte   1               ; ReadBlock
        .word   plist
        bcs     fail
        inc     blk
        inc     buf + 1
        inc     buf + 1         ; the next 512 bytes
        dec     count
        bne     read
        lda     vec             ; tell stage 1 where SmartPort is
        sta     SPENTRY
        lda     vec + 1
        sta     SPENTRY + 1
        jmp     STAGE1
fail:   lda     $c034
        and     #$f0
        ora     #1              ; red border
        sta     $c034
halt:   bra     halt
count:  .byte   0
plist:  .byte   3, UNIT
buf:    .word   STAGE1
blk:    .byte   1, 0, 0
