; Codename Droid for the C64: one assembly unit. The BBC game (build/gen/game.s, data.s, made from
; bbc/src by tools/make_game_source.py) runs unchanged at its own addresses; the C64 engine is
; platform.s (start-up, hardware, OS shims, hooks) and cells.s (the screen).
.include "memmap.inc"
.include "zp.inc"
.include "symbols_c64.inc"
.include "game.s"
.include "data.s"
.include "tables.s"
.include "ring_macros.s"
.include "ring_ops.s"
.include "cells.s"
.include "sound.s"
.include "intro.s"
.include "platform.s"

.assert __DROID_SIZE__ = $4700, error, "the game segment must stay the size of the BBC's (no address may move)"
.import __DROID_SIZE__
