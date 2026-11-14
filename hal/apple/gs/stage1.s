; Apple IIgs stage 1 loader. Entered from stage 0 in emulation mode (D = 0, DBR = 0). For each entry of the load table
; (made by tools/make_apple2gs_disk.py: disk block, block count, destination address, destination bank) it reads the
; blocks one at a time through SmartPort into BOUNCE and copies each to its place with a block move, then jumps to the
; entry point in native mode with 16-bit registers, D = 0 and DBR = 0.
;
; SmartPort is called from emulation mode with D = 0, DBR = 0 (Firmware Reference ch. 7), so each read switches
; mode and back. A failed read, or an entry that would cross a bank, turns the border red and stops.
.p816
.smart +
.include "loader.inc"

.segment "ZEROPAGE"
tptr:   .res 2                  ; the table entry being loaded
blk:    .res 2                  ; the next disk block
count:  .res 2                  ; blocks left in this entry
dest:   .res 2                  ; the next destination address (in its bank)

.segment "CODE"
stage1:
        clc
        xce                     ; native mode
        rep     #$30
        .a16
        .i16
        lda     SPENTRY
        sta     spv             ; SmartPort's address into the JSR below
        lda     #loadtab
        sta     tptr
next_entry:
        ldy     #2
        lda     (tptr),y        ; block count; zero ends the table
        beq     finished
        sta     count
        ldy     #0
        lda     (tptr),y
        sta     blk
        ldy     #4
        lda     (tptr),y
        sta     dest
        ldy     #6
        lda     (tptr),y        ; destination bank (low byte)
        sep     #$20
        sta     mvn_op + 1      ; the block move's destination bank
        rep     #$20
next_block:
        jsr     read_block
        ldx     #BOUNCE
        ldy     dest
        lda     #511
mvn_op: mvn     $000000,$000000 ; the destination bank is patched above: source bank 0
        pea     $0000
        plb
        plb                     ; data bank back to 0 (the move left it at the destination bank)
        lda     dest
        clc
        adc     #512
        sta     dest
        bcs     fail            ; the entry crosses a bank
        inc     blk
        dec     count
        bne     next_block
        lda     tptr
        clc
        adc     #8
        sta     tptr
        bra     next_entry
finished:
        jmp     (entry)

; read disk block `blk` into BOUNCE (native mode in, native mode out)
read_block:
        lda     blk
        sta     plist + 4
        sep     #$20
        lda     #0
        sta     plist + 6
        sec
        xce                     ; emulation mode: SmartPort needs it
        .byte   $20             ; JSR dispatch, patched above
spv:    .word   $ffff
        .byte   1               ; ReadBlock
        .word   plist
        bcs     fail
        clc
        xce                     ; back to native mode
        rep     #$30
        rts
fail:   sep     #$30            ; reached in either mode: use 8-bit registers
        .a8
        .i8
        lda     $c034
        and     #$f0
        ora     #1              ; red border
        sta     $c034
halt:   bra     halt

plist:  .byte   3, UNIT
        .word   BOUNCE
        .byte   0, 0, 0         ; the block number, filled in for each read

; the load table and the entry address, made by tools/make_apple2gs_disk.py:
;   loadtab: entries of 8 bytes (first disk block, block count, destination address, destination bank, 0), ended by
;   a zero count; entry: the address to run
.include "loadtab.inc"
