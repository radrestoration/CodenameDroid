; Apple IIgs platform layer for the game logic (built from src/ with logic_hal.s into bank 2).
;
; Entered in native mode from stage 1. Sets up Super Hi-Res and the logic's RAM in bank 2 and starts the logic (logic_start),
; which runs the title screen and a new game and ends in the main loop here (plat_main): every video frame wait for the
; vertical blank, read the keyboard into KEYBITS (which the logic's hal_scan_keys copies), run the logic's `compute_frame` (keys,
; game steps, camera, view), and show the result with shr_present. The main loop runs in emulation mode in bank 0 (D = 0,
; DBR = 0); logic routines are called through the trampolines in bank 2 (tramp.s) and the logic's variables are reached with long
; addresses. The logic's own waits and character writes come back here through the table at the start of this segment.
;
; Keys (one ordinary key at a time, plus the Apple keys and Shift, since the IIgs keyboard register shows only the newest key):
;   X / right arrow: right   Z / left arrow: left   ; / up arrow: up   / or down arrow: down   RETURN: jump   = : fire
;   Open Apple (GSplus: F1) or Shift: jump (hold it with X or Z to jump sideways)   Closed Apple/Option: fire
;   A J D O S B M P DEL ESC TAB SPACE as the C64 port
.p816
.smart +
.include "logic_syms.inc"
.include "game.inc"
.import shr_init, shr_present, shr_present_hold
.export platform_start, plat_main, main_loop, plat_frame, plat_wait_frames, read_host_keys
.import shr_char_hook

; Border colour as a speed gauge (emulation mode, 8-bit A): black while waiting for the next video frame, red while the game's
; logic runs, green while the picture is drawn. On a machine with time to spare most of the border is black; if the border is
; never black, a frame takes longer than 1/60 s and the game runs slower than real time.
.macro border colour
        lda     f:$e0c034
        and     #$f0
        ora     #colour
        sta     f:$e0c034
.endmacro

; The platform's entry points at fixed addresses (game.inc): stage 1 jumps to $2000, and tramp.s's reverse trampolines (the logic's
; frame_wait, wait_frames, hal_store_char and hal_main) reach the rest through the table.
.segment "PBSS"                 ; the platform's variables, in bank 0 (the data bank is 0 where they are used; the zero page is the logic's)
fresh:    .res 1
lastkey:  .res 1
wanted:   .res 1
mods:     .res 1

.segment "ENTRY"
        jmp     platform_start
        .res    1
        .assert * = PLAT_FRAME, error, "the entry table is in the wrong place"
        jml     plat_frame
        jml     plat_wait_frames
        jml     shr_char_hook
        jml     plat_main

.segment "CODE"

platform_start:
        clc
        xce
        rep     #$30
        .a16
        .i16
        ; ---- Super Hi-Res: palette 0, scan-line control bytes, then the mode (after the first present, below)
        ldx     #PALETTE_SRC
        ldy     #$9e00
        lda     #32 - 1
        mvn     $000000,$e10000
        pea     $0000
        plb
        plb
        sep     #$20
        .a8
        ldx     #0
        lda     #0
scb:    sta     f:$e19d00,x
        inx
        cpx     #200
        bne     scb
        rep     #$20
        .a16
        ; ---- the logic's RAM in bank 2: $0200-$05FF (its BSS) zero
        sep     #$20
        .a8
        lda     #0
        sta     f:LOGIC + $0200
        rep     #$20
        .a16
        ldx     #$0200
        ldy     #$0201
        lda     #$0600 - $0200 - 2
        mvn     $020000,$020000
        pea     $0000
        plb
        plb
        sec
        xce                     ; emulation mode from here on
        .a8
        .i8
        jsl     shr_init
        lda     f:$e0c029       ; Super Hi-Res on, linear: read-modify-write (bit 0 is the monitor's)
        ora     #$c0
        sta     f:$e0c029
        lda     f:$e0c034
        and     #$f0            ; black border
        sta     f:$e0c034
        jsl     TR_START | LOGIC        ; the logic: tables, title screen, a new game; it ends in plat_main (and does not come back)

; the logic's hal_main: the main loop
plat_main:
        phk
        plb                     ; data bank 0
        jsl     shr_present     ; the first picture of the game (new_game staged it)
main_loop:
        border  0
        jsr     wait_vbl
        border  1
        jsr     read_host_keys
        lda     f:LOGIC + L_tick
        clc
        adc     #1
        sta     f:LOGIC + L_tick
        lda     #1              ; one frame since the last
        sta     f:LOGIC + L_dt
        jsl     TR_COMPUTE_FRAME | LOGIC
        lda     #0
        sta     f:LOGIC + L_ready       ; what the C64's raster interrupt does with the staged picture:
        border  4
        jsl     shr_present             ; show it (and the logic may stage the next)
        bra     main_loop

; wait for the start of the next vertical blank, then for its end ($C019 bit 7 is 0 during the blank)
wait_vbl:
        lda     f:$e0c019
        bmi     wait_vbl
vbl_end:
        lda     f:$e0c019
        bpl     vbl_end
        rts

; ---- the keyboard
; The newest key waiting wins (a queue of up to 8 builds up behind slow frames, and every read of $C010 moves it on), then
; $C010's bit 7 says whether a key is still down. A tap that ended before we looked still counts for this frame.
read_host_keys:
        lda     #0
        sta     f:LOGIC + KEYBITS
        sta     f:LOGIC + KEYBITS + 1
        sta     f:LOGIC + KEYBITS + 2
        stz     fresh
        lda     f:$e0c000
        bpl     no_new
new:    and     #$7f
        sta     lastkey
        inc     fresh
        lda     f:$e0c010
        lda     f:$e0c000
        bmi     new
no_new: lda     f:$e0c010
        bmi     ordinary
        lda     fresh
        beq     modifiers
ordinary:
        lda     lastkey
        cmp     #'a'
        bcc     look
        cmp     #'z' + 1
        bcs     look
        sbc     #$1f            ; lower case to upper (carry is clear here: A - $20)
look:   sta     wanted
        ldx     #0
search: lda     keymap,x
        beq     modifiers
        cmp     wanted
        beq     found
        inx
        inx
        bra     search
found:  lda     keymap + 1,x
        jsr     set_key_bit
modifiers:
        lda     f:$e0c025       ; bit 7: Open Apple, bit 6: Closed Apple / Option
        sta     mods
        bmi     do_jump
        lda     mods
        and     #$01            ; Shift also jumps: Open Apple is often grabbed by the desktop on the host
        beq     no_open
do_jump:
        lda     #K_JUMP
        jsr     set_key_bit
no_open:
        lda     mods
        and     #$40
        beq     no_closed
        lda     #K_FIRE
        jsr     set_key_bit
no_closed:
        rts

; set_key_bit: key number A (1 - 20) is held: bit A - 1 of the three bytes of KEYBITS
set_key_bit:
        sec
        sbc     #1
        pha
        lsr     a
        lsr     a
        lsr     a
        tax
        pla
        and     #7
        tay
        lda     keybit,y
        ora     f:LOGIC + KEYBITS,x
        sta     f:LOGIC + KEYBITS,x
        rts

keybit: .byte   $01, $02, $04, $08, $10, $20, $40, $80

.include "keymap.inc"

; ---- for the logic's own waits (frame_wait, wait_frames and HAL_WAIT_SHOWN): called with JSL from the logic, in emulation mode
; plat_frame: one frame passes: wait for the vertical blank, read the keys, count the tick, and do what the C64's interrupt would
; with a staged picture (show it). plat_wait_frames: A frames of that.
plat_frame:
        jsr     wait_vbl
        phb                     ; (the logic's data bank is 2; the key table is in bank 0)
        lda     #0
        pha
        plb
        jsr     read_host_keys  ; (the modal screens wait for keys inside the logic: the C64's CIA is live, KEYBITS has to be)
        plb
        lda     f:LOGIC + L_tick
        clc
        adc     #1
        sta     f:LOGIC + L_tick
        lda     f:LOGIC + L_ready       ; the matrix is live on the C64 (the VIC-II reads it); the sprite registers and the
        beq     matrix_only             ; scroll register are taken over by the interrupt only when `ready` is set
        lda     #0
        sta     f:LOGIC + L_ready
        jsl     shr_present
        bra     frame_done
matrix_only:
        jsl     shr_present_hold
frame_done:
        rtl

plat_wait_frames:
        pha
wf:     pla
        beq     wf_done
        sec
        sbc     #1
        pha
        jsl     plat_frame
        bra     wf
wf_done:
        rtl
