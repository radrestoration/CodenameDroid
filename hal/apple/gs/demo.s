; Apple IIgs demo, the first thing the loader runs: set up Super Hi-Res, draw a level and scroll it with the keys.
;   Z / left arrow: scroll left     X / right arrow: scroll right     K / up arrow: up     M / down arrow: down
; The level data, tile art and palette were loaded to their places by stage 1 (see tools/make_apple2gs_disk.py).
; This uses the tile-based draw_view/scroll routines of draw.s, the earlier experiment: its level maps lack the lift
; pieces the game adds, so this is a look at the art and a test of the loader, not the game.
.p816
.smart +
.include "loader.inc"
.import draw_view, scroll_left, scroll_right, scroll_up, scroll_down
.importzp cam_x, cam_y
.export demo_start, wait_key

PALETTE_SRC = $1c00             ; palette.bin, loaded here (16 entries of 2 bytes)

.segment "CODE"
demo_start:
        clc
        xce
        rep     #$30
        .a16
        .i16
        ; palette 0 of Super Hi-Res: 32 bytes to $E1:9E00
        ldx     #PALETTE_SRC
        ldy     #$9e00
        lda     #32 - 1
        mvn     $000000,$e10000
        pea     $0000
        plb
        plb                     ; the move left the data bank at $E1
        ; scan-line control bytes: palette 0, 320 mode, for all 200 lines
        sep     #$20
        .a8
        ldx     #0
        lda     #0
clear_scb:
        sta     f:$e19d00,x
        inx
        cpx     #200
        bne     clear_scb
        rep     #$20
        .a16
        lda     #179            ; where a new game starts the camera on level 0 (what the C64 logic's init_view makes), under the ship
        sta     cam_x
        stz     cam_y
        lda     #0              ; level 0
        jsr     draw_view
        sep     #$20
        .a8
        lda     f:$e0c029       ; Super Hi-Res on, linear: read-modify-write, bit 0 is the monitor's
        ora     #$c0
        sta     f:$e0c029
        rep     #$20
        .a16
; ---- keys
        sep     #$20
        .a8
        lda     f:$e0c034       ; border black
        and     #$f0
        sta     f:$e0c034
        rep     #$20
        .a16
; Keys. The newest key wins: GSplus (like the real keyboard buffer) queues up to 8 key events, and while a key is held
; auto-repeat events pile up behind slow scrolls, so a new key would wait behind stale ones and the old direction would
; seem to stick. Each time round, every waiting key is read and only the last kept.
; Holding a key keeps scrolling at once: $C010 reads back "a key is still down" in bit 7 (the keyboard's own flag), so
; the system's repeat delay is not waited for. A tap that is over before we look still scrolls once (`fresh`). Reading
; $C010 also moves the key queue on, so it is only read after the queue has been emptied.
wait_key:
        sep     #$20
        .a8
        stz     fresh
        lda     f:$e0c000
        bpl     no_new
new:    and     #$7f
        sta     key
        inc     fresh           ; a key arrived since the last scroll
        lda     f:$e0c010       ; clear the strobe: the next queued key, if any, moves up
        lda     f:$e0c000
        bmi     new             ; keep the newest
no_new: lda     f:$e0c010       ; the queue is empty: bit 7 says whether a key is still down
        bmi     act
        lda     fresh
        beq     wait_key        ; nothing new and nothing held
act:    rep     #$20
        .a16
        lda     key
        and     #$00ff
        cmp     #'a'
        bcc     upper
        sec
        sbc     #$20            ; lower case to upper
upper:  cmp     #'Z'
        beq     go_left
        cmp     #$08
        beq     go_left
        cmp     #'X'
        beq     go_right
        cmp     #$15
        beq     go_right
        cmp     #'K'
        beq     go_up
        cmp     #$0b
        beq     go_up
        cmp     #'M'
        beq     go_down
        cmp     #$0a
        beq     go_down
        bra     wait_key
go_left:
        jsr     scroll_left
        bra     wait_key
go_right:
        jsr     scroll_right
        bra     wait_key
go_up:
        jsr     scroll_up
        bra     wait_key
go_down:
        jsr     scroll_down
        bra     wait_key

key:    .res    2
fresh:  .res    1
