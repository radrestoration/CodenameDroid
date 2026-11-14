; The game logic for the Apple IIgs: the shared sources (src/) with this directory's HAL (logic_hal.s), built to run in bank 2 in
; the 65816's emulation mode, loaded at $0801 (hal/apple/gs/logic.cfg). The platform (platform.s, bank 0) shows what it stages.

.setcpu "65816"
.include "game_data.inc"

.include "memory.inc"
.include "constants.inc"
.include "hal.inc"
.include "vars.inc"

.segment "CODE"
.include "logic_hal.s"
.include "frame.s"
.include "init.s"

.include "level.s"
.include "view.s"
.include "input.s"
.include "player.s"
.include "objects.s"
.include "enemy.s"
.include "blaster.s"
.include "events.s"
.include "lift.s"
.include "screens.s"
.include "title.s"
.include "sfx.s"
