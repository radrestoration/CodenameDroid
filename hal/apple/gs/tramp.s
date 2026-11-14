; Trampolines in bank 2 (the logic's bank), so the platform in bank 0 can call logic routines: JSL from emulation mode.
; Each sets the data bank to 2 (the logic's absolute addressing), calls the routine, restores the caller's data bank, and
; returns long. The registers the routine leaves are returned except the flags, which the last PLB overwrites.
; Linked at $0700 of bank 2 (tramp.cfg); the image also carries the (zeroed) 256 bytes below it, MIRROR_TABLE's page.
.p816
.include "logic_syms.inc"
.include "game.inc"

.macro tramp name, target, slot
        .assert * = TRAMP + slot * 16, error, "trampoline in the wrong place"
name:   phb
        pea     $0202
        plb
        plb                     ; data bank = 2
        jsr     target
        plb
        rtl
        .res    16 - 11
.endmacro

.segment "CODE"
        tramp   tr_compute_frame, L_compute_frame, 0
        .res    TR_START - TR_COMPUTE_FRAME - 16
        .assert * = TR_START, error, "tr_start in the wrong place"
tr_start:                       ; the logic's first routine, with the data bank 2; it never comes back, so nothing is restored
        phb
        pea     $0202
        plb
        plb
        jmp     L_logic_start
        .res    HAL_FRAME - TR_START - 9

; the other way: what the logic's frame_wait, wait_frames, hal_store_char and hal_main are (see logic_hal.s): the platform's routines
; (the table in platform.s) called from the logic's bank, with JSL and back with RTS. 8 bytes each.
        .assert * = HAL_FRAME, error, "the stubs are in the wrong place"
        jsl     PLAT_FRAME
        rts
        .res    3
        jsl     PLAT_WAIT
        rts
        .res    3
        jsl     PLAT_CHAR
        rts
        .res    3
        .assert * = HAL_MAIN, error, "hal_main in the wrong place"
        jml     PLAT_MAIN
