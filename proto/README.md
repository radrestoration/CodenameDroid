# Engine prototype

A first look at a C64-native engine for Codename Droid: the game's level (Surface Defence sector two) in character mode with
smooth sideways scrolling, and the player and three enemies as hardware sprites, walking and jumping by the BBC game's own
checks of the screen. It is not the game: no objects, ropes, lifts, kneeling, blasters, sound or levels but the one.

    make proto          build/proto/proto.prg (the data is made from the BBC game's own level and sprites)
    proto/run.sh        build and run in VICE  (proto/run.sh ntsc  for an NTSC machine)

Keys: Z / X walk left and right, RETURN jumps (hold Z or X for a jump to that side); joystick 2 does the same (left, right, fire).

**The border shows the time**: blue is the game's step and the sprites, red the screen matrix being rebuilt (once a cell, about
10,000 cycles), black is idle. A frame is 19,656 cycles (PAL) or 17,095 (NTSC): when the work runs on into the next frame the
bars reach the top of the screen and the picture is a frame late.

## How it works

- **The background is the level's character numbers** (`ROWS`: 32 rows of 256 cells, from the BBC's 64 x 8 tiles of 4 x 4 cells).
  The level needs 104 distinct characters; the character set is made once, offline. Nothing is converted or looked up while the
  game runs: the screen matrix is a window onto `ROWS`.
- **Scrolling** moves the window a cell at a time, as the game does (a step every 4 PAL frames, 4.8 NTSC), and the VIC-II's fine
  scroll moves the picture 2 pixels a frame between: smooth where the BBC jumped. When a cell boundary is crossed the other
  matrix is made (the shown one shifted by a block copy, a new column of 25 cells from `ROWS`) and the raster interrupt swaps it in
  together with the fine scroll and the sprite registers, in the top border, so nothing tears. 38-column mode hides the edges
  of the fine scroll, so the picture is 38 cells wide.
- **The camera** (25 of the level's 32 rows) moves a row at a time by the same shift.
- **Sprites**: each actor is two (the upper 21 lines and the lower 11 of its 24 x 32 pixels). The sprite data is the game's own
  sprites, converted; the palette is the same three colours, so characters and sprites match. Enemies on the screen are shown;
  more than four actors would need the interrupt to reuse sprites down the screen (not done).
- **The rules** are the BBC's, from its disassembly: a wall is any non-blank byte in the column beside the player (scanned
  down its 32 lines), sloping ground of 4 or 8 lines is climbed, the ground is the byte under the three cells at the feet, the
  head the byte above them; a jump is 12 steps of 4 lines (10 for a vertical one), a fall 4 lines a step; the walking frames are
  0 1 2 0 3 4. The checks read `BPAT`, the level's own bytes.

## What it shows (in the headless simulator; not tried in VICE)

Work per frame, PAL: 6,100 cycles on average, 12,900 at most (the frame a matrix is rebuilt, which is one in four); NTSC 4,500
and 12,600 of 17,095. The whole of the walking, the scrolling and four actors fit with room to spare, where the BBC engine's
port needs 94,000 cycles a step just to scroll.

Not in it: the player's collision with enemies and blasters, objects, the lift and rope rules, the other levels (the generator
takes a level number: `make proto PROTO_LEVEL=3`), sound, the status screens. The sprite overlays the background, where the BBC's
sprites overwrote it; an enemy walking past a wall shows the wall behind it.
