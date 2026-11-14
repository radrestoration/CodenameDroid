; The C64's side of the contract with the shared game logic (see hal/README.md).

IRQLINE     = 20                ; the raster line of the frame interrupt

; the border shows the time in a build with PROFILE: blue the game, red the screen matrix, black idle
.macro BORDER colour
.ifdef PROFILE
    lda #colour
    sta $d020
.endif
.endmacro


; ---- the contract's macros (small enough to be inlined) ----------------------------------------------------------------------

; HAL_WAIT_SHOWN: the logic has set `ready` (a picture is staged): wait until the display has taken it over. The C64's raster
; interrupt does that, and clears `ready`.
.macro HAL_WAIT_SHOWN
:   lda ready
    bne :-
.endmacro

; the RAM under the C64's I/O area is visible to the CPU / the I/O area is back (the sprite blocks live under it)
.macro HAL_RAM_UNDER_IO
    lda #$34
    sta $01
.endmacro

.macro HAL_IO_VISIBLE
    lda #$35
    sta $01
.endmacro

; HAL_SPRITES_ENABLE: the sprite enable mask is in A
.macro HAL_SPRITES_ENABLE
    sta $d015
.endmacro
