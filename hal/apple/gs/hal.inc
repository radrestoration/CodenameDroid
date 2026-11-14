; The Apple IIgs side of the contract with the shared game logic (see hal/README.md), for the logic's own code (bank 2, 6502
; emulation mode). The routines are stubs that call the platform in bank 0 (hal/apple/gs/platform.s) through tramp.s's reverse
; trampolines; game.inc has their addresses.
.include "game.inc"

; the platform's per-frame work: a staged picture (`ready`) is shown, and the platform counts `tick`
.macro HAL_WAIT_SHOWN
    jsr frame_wait
.endmacro

; there is no I/O area over the RAM, no sprite chip and no timing aid
.macro HAL_RAM_UNDER_IO
.endmacro

.macro HAL_IO_VISIBLE
.endmacro

.macro HAL_SPRITES_ENABLE
.endmacro

.macro BORDER colour
.endmacro
