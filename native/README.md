# The native engine

A C64-native rewrite of the game's engine: the BBC game's rules (ported routine by routine from `bbc/src/droid.s`), on a
character-mode display with smooth sideways scrolling, the player as hardware sprites, enemies and objects as characters.
It replaces the port that ran the BBC's own code (`src/`), which was too slow for scrolling with enemies. Not yet part of
`make` / `make zip`.

    make native                 build/native/game.prg
    make native CHEAT=1         build/native-cheat/game.prg   (test keys, below)
    make native PROFILE=1       build/native-profile/game.prg (the border shows the time: blue the game, red the screen matrix)
    native/run.sh [ntsc] [cheat] [intro] [warp]       build and run in VICE (intro: from build/native/droid.d64, the loading screens first)

Keys are the port's: Z / X walk, `;` up, `/` down, RETURN jump (with Z or X for a jump to the side), `=` fire, A wrist
terminal (S, B charge the suit and the blaster, M map, SPACE leave), J jet pack computer, D drop a mine, O leave the jet
pack, P pause (P or DEL resume), F1 / F3 sound off / on, CTRL lose a life, RUN/STOP give up; joystick 2 walks, up, down, jumps.
Cheat build: 1-9, 0, Q, W go to levels 1-12 (at the right lift), E fills energy, pass cards and cells, R gives the
microfilm, the key and the spanner, T the jet pack.

## How it works

- **The level** (`level.s`): at level load the BBC's tiles (4 x 4 cells, from the BBC game's own tile art, flips and all)
  are made into characters, each distinct 8-byte cell once (`intern`: hashed, compared), at most 203 a level (the largest
  needs 179). The level is `ROWS`, 32 rows of 256 character numbers, and `BPAT`, each character's BBC bytes, which the
  rules read as the BBC reads its screen. The map of tiles (`LTILES`, a page a level) is the BBC's, edited by the game's
  events (lifts, pillars, doors...).
- **The display** (`view.s`): a window of 40 x 25 cells onto `ROWS`, in two screen matrices (`$c800`, `$cc00`), one shown
  while the other is made (the shown one shifted by a block copy, a new column or row from `ROWS`), and the raster interrupt
  swaps them together with the VIC-II's fine scroll and the sprites, so nothing tears. 38-column mode hides the scroll's
  edges. The camera shows 25 of the level's 32 rows and moves by a row.
- **The player** is two sprites (21 + 11 lines; three for crawling, which is 7 cells wide), moved smoothly toward where the
  game's step has put it; **blasters** are sprites 3 - 7; **enemies, objects, mines and explosions** are characters written
  into `ROWS` and both matrices (`put_cell`) as they change. Each visible enemy keeps the twelve cells under its picture so
  they can be put back; the character groups start after the current level's glyphs and scale to the available space, up to
  ten groups. Enemies and the player's collisions use the BBC's way: a point of the player's picture
  against the enemy's byte.
- **The rules** (`player.s`, `objects.s`, `enemy.s`, `blaster.s`, `events.s`) keep the BBC's names and order of play:
  `game_step` is its main loop without the display, run every 4 PAL frames (4.8 NTSC), as the BBC's loop took 4. The BBC keeps
  the player as a screen address; here `pc` (cell column) and `py` (line) are that address, `px` the BBC's `player_x`.
- **Screens** (`screens.s`, `title.s`): the wrist terminal, the map, the jet pack computer, game over and the completion
  screen are made of characters too (a backdrop of tiles as level 12 / 13, the BBC's font as shared glyph characters, its
  sprites composited into the cells under them); the title is the BBC's own screen, taken from the BBC game running in
  `tools/bbcsim.py`, with the player walking on the spot and firing.
- **Sound** is the C64 port's SID driver (`src/sound.s`) with the BBC's sound calls (`sfx.s`).

## Memory

The program and sprite source blocks occupy `$0801-$9fff`. `$a000-$bfff` is `ROWS`; `$c000` is the active character set,
`$c800` / `$cc00` the screen matrices, and `$d000-$dfff` the sprites (VIC-II bank 3). The lift temporarily uses `$d000`
for its ride charset, `$d800` for the rebuilt level charset, and `$de80-$df3f` for the player's ride sprites; this all sits
under the I/O area, which the CPU maps out only while copying. `$e000` is `LTILES`, `$ee00` `BPAT`, `$f600` the sharing
tables, `$fa00` the sound driver's variables; `$0200` variables.

## Checking it

`tools/make_native_data.py` makes `native_data.inc` (tiles, levels, sprites, the title...) from the BBC game's own data.
`native/sim_check.py` runs it headless (6502 simulator, a model of the raster, keys and interrupts) and renders the screen.
`tools/test_native_enemy_pool.py` checks the new-game start and character-group capacity on the two crowded early levels.
`tools/test_native_lift.py` exercises the ride, next-level rebuild, and charset/sprite display handoff in the raster simulator.
`tools/test_native_vs_bbc.py [iterations] [seed] [deepest]` runs it against the BBC game with the same keys: after each pass
of the main loop the player's state, the energies, the objects carried and the enemies' variables must agree. They do, for
hundreds to thousands of iterations on levels 0, 3 and 6, with random play; where they differ the BBC's own pixels are the
cause (its sprites leave remnants and carve holes in the ground, which the rules then read; here the sprites are not in the
level). The collisions with enemy fire, mines and the terminal are not in that test.

## Differences from the BBC

- Enemies move a cell at a time as on the BBC, while the picture scrolls smoothly; the player and bullets move smoothly.
- The screen shows 25 of the level's 32 rows (the camera), and 40 of its columns instead of 32.
- Sprites do not overwrite the background, so a player or an enemy in front of a rope or a chain leaves it showing.
- The title does not scroll in. The instruction pages, the pictures and the credits (the BBC disc's front end, `src/intro.s`) are a program of their own, `intro/` -> `build/native/intro.prg`: it shows them, then loads `GAME` over itself and runs it (`droid.d64` has both; `game.prg` alone starts at the title). Not run on a C64 or in VICE: the sim reaches its KERNAL LOAD call.
- A lift ride (`lift.s`) scrolls the 40 columns at the lift's end of the old and new levels past the fixed cabin and player.
  The new level is built into separate row/charset storage while the ride remains visible, then the display switches to the
  rebuilt level at landing without the former black rebuild.
- Mines exploding use the cell of the mine, not the half cell the BBC may use; the pillars of the shrine's sector three kill by
  a test of the player's four points against the pillar's cells.
