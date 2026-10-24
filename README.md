# Codename Droid - C64 port

The BBC game (rebuilt bit-for-bit in `bbc/`, see `bbc/README.md`) running on a C64, in a window 40 cells wide instead of
the BBC's 32 (the BBC's own 32 is a build option, `WIDE=32`). **It has not been run on a C64 or in
VICE** - everything below was checked in a headless 6502 simulator only (see "Verification").

    make            build/c64/droid.prg (and droid.d64); builds the BBC game into build/bbc first
    make WIDE=32    the same with the BBC's 32-cell window (into the same directory)
    make test       the headless checks (minutes; `make test WIDE=32` for the 32-cell build's)
    make levels     render the 12 levels to build/c64/levels/*.png
    make zip        build/c64/codename-droid-c64.zip: the PRG, the disk image, a VICE run script (`tools/dist_run.sh`) and a README
    ./run.sh        build and run in VICE (`ntsc`, `d64`, `warp`, `narrow` arguments)

Run it: `x64sc build/c64/droid.prg` (autostart), or load `build/c64/droid.d64` and `LOAD"DROID",8,1` then `RUN`. It detects
PAL and NTSC itself. (The text below describes the 32-cell layout, the BBC's, where the two differ the 40-cell one is
described under "The 40-column window".)

## Loading screens

The game starts, as the BBC disc does, with its front end's screens (`src/intro.s`; the data is made from the original disc
by `tools/make_intro.py`; nothing from a BBC ROM is used):

0. the **instruction pages** from the tape inlay (11 pages: the story, the zones, the wrist terminal, ...). On the BBC they
   are MODE 7 text from the disc's BASIC program `DROID`; `tools/mode7.py` runs that program's PRINT statements on a
   40 x 25 teletext screen and turns each page into C64 text mode in the C64's own lower case character set. Colours
   become C64 colours; a background colour (the title bar) is reverse video; flashing and double height are not done.
   SPACE (or fire) for the next page, RUN/STOP skips them all.
1. the logo, 2. a full screen picture (each 8 seconds, or any key), 3. PRESENTING, the logo strip and the credits -
   SPACE (or fire) starts the game, V shows the controls (then the wrist terminal's, SPACE for each, and back). The
   controls pages are for the C64's keys.

The pictures are the BBC's MODE 1 screens (320 x 256, four colours) scaled to the C64's multicolour bitmap (160 x 200:
nothing is cropped, but the pictures lose their horizontal detail and small text goes soft); each picture has the same
three colours in every cell, so only the bitmap is stored, LZ77-packed (2.3 and 5.9 KB). The logo screen keeps its 184 rows and is drawn in two modes, switched by polling the raster
(`intro_pause_split`): the logo's letters (down to raster line 155, in the black between them and the caption) are multicolour,
160 wide, red outlines kept whole; below that the caption and the Superior / Acornsoft block are **hires**, 320 wide, so the
white text stays sharp, with the two colours (of black, red, blue, white) that suit each 8 x 8 cell best - the red and white
of the Superior "S" clash a little. The credits' logo strip keeps its rows and loses half its width, without dithering;
the full screen picture is 256 rows, so it is scrolled (below). The credits and controls are a
character screen: the capitals are the front end's own (it redefines them, `VDU 23` in its listing, which the tool
reads), the digits and punctuation the C64's character ROM's (copied when the page is shown), and the logo strip is
multicolour characters. The BBC program flashes its second colour between blue and green once a frame, which leaves it
green: the strip and the last lines are green here. The pictures and the credits are in VIC-II bank 3
(`$c000-$ffff`: the bitmap or character set at `$e000`, screen RAM in the RAM under the I/O area at `$d000`), so the
game's memory is untouched; the sound driver and tables are moved into place afterwards. The build needs the disc image
(`DISC`, default `~/retro/games/Disc032-...ssd`); without it there are no loading screens. `tools/shots_intro.py` renders
pages to `build/c64/shots`.

**The scrolled picture** (WIDE=40 only): the full screen art is all 256 rows, two pixels to one across with the same colour
priority and no dithering. The window shows 192 lines, so it moves up 64, a line every 3 frames (60 ms on PAL; 3.6 frames
on NTSC, so the time is the same), after a pause at the top and before one at the bottom: 130 steps, about 7.8 seconds, or
until a key. The fine scroll is the VIC-II's YSCROLL (24-row mode, so the border hides the clipped lines); every 8 lines the
bitmap moves up a cell row, which is 7,700 bytes: that is made in a second bitmap (bank 1, `$6000`; the first is bank 3)
two cell rows a frame, taking the picture's last 7 rows from RAM under the I/O area, and the VIC-II is switched to it in
the blank lines at raster line 252, so nothing tears. Everything is done at that line, so the timing is the frame count.
`test_intro.py` checks every frame's bank, fine scroll and bitmap against the picture, and the pace. Not seen in VICE.

## Controls

| | keyboard | joystick (port 2) |
|---|---|---|
| walk | Z / X | left / right |
| up (climb, lift, stand) / down (kneel, crawl, descend) | `;` / `/` | up / down |
| jump (hold Z or X for a sideways jump) | RETURN | fire |
| fire the blaster | `=` | |
| wrist terminal / jet pack screen | A / J | |
| drop a mine / leave the jet pack | D / O | |
| pause / resume | P / DEL | |
| lose a life / give up | CTRL / RUN-STOP | |
| sound off / on | F1 / F3 | |

On the wrist terminal: S and B charge the suit and the blaster, M shows the map, SPACE leaves. These are the BBC's keys
moved to where the C64 has them (the BBC `]` is `=`, its up key is `;`); they are one table, `keytab` in `src/platform.s`.

## How it works

The game's own code runs **unchanged** on the C64, at its BBC addresses: the game at `$1100-$57ff`, its tile graphics at
`$5800`, its data blocks moved to `$0300-$10ff` at start-up, and its screen buffer at `$6000-$7fff` (32x32 cells of 8
bytes, in BBC MODE 5 format: the game draws and reads pixels there exactly as on the BBC). `tools/make_game_source.py`
makes the C64's copy of the source from `bbc/src` with a short list of patches, every one the same size as what it
replaces (the game has hard-coded addresses into its own code, so nothing may move):

- zero page `$00-$03` (the BBC's enemy variables, and the C64's CPU port!) live at `$e4-$e7`;
- the few hardware accesses (CRTC, VIA, ULA) and the OS calls (vsync, palette, sound, key read) go to shims;
- the six routines that draw into the buffer get an entry hook that reports which cells they changed;
- `variable_delay` (a busy-wait that paces the BBC's scrolling) returns at once; `update_chandeliers` has a faster
  equivalent (it scanned the whole level every few frames).

`src/cells.s` turns the changed cells into what the VIC-II shows. A character is chosen for each distinct 8-byte cell
pattern (hashed, shared between cells, reference-counted, kept after its last use so a returning pattern costs nothing);
the screen is a 25-row multicolour character matrix (VIC bank 2: charset `$a000`, two matrices `$a800` and `$ac00`, one shown while the other is built). Scrolling changes no
pixels: the matrix is just read from the buffer at a different start. BBC logical colours 0-3 (black, red, cyan, white)
are the C64's pixel values 0-3 (`$d021`, `$d022`, `$d023`, colour RAM).

The BBC shows 256 lines and the C64 200, so the matrix shows 25 of the buffer's 32 cell rows. In play the camera sits on
rows 4-28 (the playing area between the wall ceiling and floor) and moves, a row a frame, only where a level needs it (the
three levels that use the full height, and lifts). The title, status screens and game over are framed screens with their
content in rows 4-27, so they show fully with the default view; only their decorative top and bottom frame edges are cut.
The title screen is shown in 24-row mode (`$d011` RSEL = 0, YSCROLL 7, so the matrix starts at the window's first line):
exactly ring rows 4-27, centred, with a four-line border band above and below and no frame wall at either end.

Scrolling right is patched so that the display is updated after the game has moved the display start, not at the
vertical-blank wait before it. The game draws the entering column, waits, then moves the start (the BBC's CRTC latches
it just after the retrace, so the two arrive together); updating at the wait showed the new column at the left edge, a
column off, on every frame (`test_scroll.py`).

A raster interrupt at line `$fb` counts the frames (the game's waits end when it has run, not at a raster line: the
interrupt takes longer than a line, and a wait for the line after it could never finish) and scans the keyboard and joystick every frame, as the BBC's OS did, so the loops that wait
for a key without waiting for the frame (game over, pause, the jet pack screen) work. The game counts vertical blanks at
50 Hz; on a 60 Hz machine a wait sometimes takes an extra frame to keep the game's speed (an account of frames owed, so
a loop that is already late never waits extra).

## Verification (headless; nothing run on a C64)

`tools/bbcsim.py` runs the original BBC build, and `tools/c64sim.py` the C64 build, in a plain Python 6502 interpreter
(`tools/sim6502.py`) with the OS and hardware modelled just enough. `make test WIDE=32` runs the 32-cell build's (below; the 40-cell default's are under "The 40-column window"):

- **same as the original**: `test_diff.py` feeds both builds the same key script and requires the same screen buffer,
  zero page and low RAM at every vertical blank. Passed for thousands of vsyncs each of random play on level 0, the
  Ancient Shrine (level 3, 10 enemies) and Crew's Quarters (level 6), through scrolling, jumping, kneeling, crawling,
  climbing and firing. This is what shows the patches and the hooks leave the game's behaviour alone.
- **pacing**: `test_pacing.py` runs the real wait routine against a model of the beam (1.2 frames per wait on NTSC when the
  game is quick, none extra when it is late, 1.0 on PAL).
- **the display**: after every frame each of the buffer's 1024 cells has a character with that cell's pixels, and the
  matrix shows the right character for every visible cell (`test_c64.py`, `test_view.py`); the camera keeps the player on
  screen (`test_camera.py`); the keyboard and joystick scan gives the two key variables the game expects (`test_keys.py`).
- **sound**: `test_sound.py` runs the driver (`src/sound.s`) with the SID's registers logged: the frequency of every BBC
  pitch (PAL and NTSC), the four-deep queues and the free count the game's tune waits on, flushing, the 1/20 s timing
  on the 100 Hz clock, the volume and envelope notes, the pitch slide, the shared third voice, the suppression switch.
- **raster**: `test_raster.py` runs the build with the real wait code and the interrupt arriving mid-instruction, PAL
  and NTSC: the title scroll finishes, SPACE starts the game, walking scrolls. (The other checks trap the wait.)
- no write to `$00/$01` anywhere in the game, and the stack never goes deeper than 42 of the 64 bytes it has.
- `tools/shots_c64.py` renders the matrix, charset and colour registers to PNGs in `build/c64/shots`, for looking at.

## The 40-column window (`WIDE=40`, the default)

The BBC's window is 32 cells (128 pixels, a square on its screen) by 32 rows; the C64 shows 25 rows. To make up the
pixels, the default build has the game's window **40 cells wide** (320 x 200, the C64's whole screen). `make WIDE=32`
(or `./run.sh narrow`) builds the BBC's 32 instead; the code is the same except the patches below, which it leaves out.

How: the game's screen buffer ("the ring") is 32 rows of `RING_W` cells; at 40 it is 10 KB at `$5800-$7fff` (it still ends
at `$8000`, where the game's sign test wraps it), with the tile graphics moved to `$8000-$87ff` and the engine to `$8800`
(`SYS 34816`). `tools/wide_patches.py` and `tools/wide_sites.py` change the game's code at about 150 places, each given
by its line in the pristine `droid.s` with the old text asserted, and each the same size as what it replaces (the game has
absolute addresses into its own code), using helpers (`ring_ops.s`, generated) where more room is needed:

- the ring's start and size (`lda #$60`, `sbc #$20` after a wrap test): symbols;
- 16-bit offsets made of two immediates (rows x 256 + cells x 8 + lines): recomputed for the stride;
- row steps (`inc screen_address_high` and the like): helpers;
- the offset tables (the player's collision points): copies for the new stride;
- what the 32 columns mean: where the window starts to scroll (x = W/2), enemies cropped at W - 4 and W, the columns at the
  edges, the lifts' tile columns, the status screens' right edge, the title's scroll counts, the start positions.
Special screens (title, terminal, map, jet pack, game over) are drawn in the leftmost 32 columns and shown cropped there.

Checks (`make test`, minutes): the helpers against a model of the ring (`test_helpers.py`); the special screens against the BBC's (`test_wide_screens.py`), and play against the
BBC's by level coordinates (`test_wide_vs_bbc.py`: the same keys, the games compared at the top of each main loop, every
cell both windows show must be the same; it stops, as intended, where the games differ for a reason: an enemy that fires
from further off in the wider window). Known differences from the BBC's play: enemies see and fire from 40 columns off;
the redraw of a level takes 40 scroll steps, not 32 (so the jet pack's energy runs down a little more in it); it is
5-10% slower than the 32-column build. The title and its intro scroll are checked against the 32-column build's
(`test_title_final.py`, which makes that build into `build/ref32`). Not run on a C64 or in VICE.

## Not verified / known gaps

- **Everything on real hardware or VICE**: the VIC-II set-up, the raster wait and interrupt, the CIA reads, the PAL/NTSC
  detection, the start-up from BASIC, timing. Reviewed by hand, never executed.
- **Speed**: the C64 has half the BBC's clock (a BBC frame is 40,000 cycles, a C64 frame 20,000), and the game's own
  drawing plus the cell store, the matrix rebuild after each scroll step (about 11,000 cycles) and the key scan add up to a
  little more than that. The player's sprite (3 cells wide) is drawn by `fast_uplayer_body` / `fast_fplayer_body` in
  `platform.s`, which write a cell at a time instead of the BBC loops' 160 cycles a pixel row (about half the cycles,
  6% of a walking-right frame; they leave exactly what the loops leave behind, checked by `test_fastplot.py` and, with
  32 cells, by the differential tests), and the key scan skips its table work when no key has changed. Walking right
  scrolls 9.4 cells a second on PAL and 10.3 on NTSC against the BBC's 11.5 (82% and 89%; before the plots 80% and 82%;
  PAL gains least because a step that overruns its frame costs a whole one; the real C64s here are NTSC); the title's intro scroll
  takes about 3 seconds on top of the start-up. A game step that takes longer than a frame does not wait for the next one
  (the picture is double buffered, so nothing needs it to). Redrawing a whole level is CPU-bound and takes about twice as
  long as on the BBC. What is left is mostly the cell store (`update_cell` and the hash lookups, about a quarter of a
  frame), the matrix rebuild (15%) and the tile columns at the window's edge.
- **Tearing**: the matrix is double buffered: the rebuild after a scroll goes to the hidden matrix, which the raster
  interrupt (line `$fb`, after the last display line) swaps in; single changed cells are written to both. Checked in the
  simulator by counting writes to the shown matrix (`test_raster.py`); not seen on a screen.
- **Sound**: written and checked in the simulator against a model (frequencies, queues, timing, envelopes), never
  heard. The envelopes are converted to SID attack/decay/sustain/release by tools/make_sound_tables.py from the game's
  own envelope data and the BBC User Guide's description of them (no BBC OS ROM was at hand to check it against);
  envelope 3 (used by the damage sound's second channel) comes out silent - its attack target is 0 - and may not be on
  a real BBC. Noise is the SID's, not the SN76489's (periodic noise is not done).
- The map screen, the jet pack screen and the completion screen are untested; the full-height levels (Surface 1, Crew's
  Quarters 2, Missile Factory 3) and lifts are only reached by the camera unit test.
- The code-adjacent limits: at most 255 distinct cell patterns on screen at once (about 250 in the worst case measured;
  past that a cell keeps its old character instead of showing a wrong one).

## Layout

| | |
|---|---|
| `src/c64.s` | the one assembly unit; `c64_40.cfg`, `c64_32.cfg` the ld65 layouts (PRG from `$0801`; start-up at `$8800`, `SYS 34816`, or at `$8000`, `SYS 32768`, with 32 cells) |
| `src/platform.s` | start-up, hardware set-up, OS shims, key scan, the entry hooks |
| `src/intro.s` | the loading screens (unpacker, pages, keys); `tools/make_intro.py` makes their data from the disc, `tools/mode7.py` runs the MODE 7 pages, `tools/detok.py` lists a BASIC program |
| `src/sound.s` | the sound driver: OSWORD 7 / OSBYTE 128 / 15 on the SID (copied to `$ee00` by start-up; variables at `$ed00`) |
| `src/cells.s` | the cell store, the matrix, the camera |
| `src/memmap.inc`, `src/zp.inc` | addresses |
| `tools/make_game_source.py` | the C64 copy of the game source, with the patches |
| `tools/make_tables.py` | lookup tables (pixel format conversion, hash, star positions, chandelier scan) |
| `tools/check_map.py` | build check: the game's code ends below `$a000`, the loading screens' data below `$d000` |
| `tools/test_fastplot.py`, `test_tables.py`, `test_intro.py`, `shots_intro.py` | the fast player plots against the BBC loops; the loading screens in the raster simulator; their pictures |
| `tools/bbcsim.py`, `c64sim.py`, `sim6502.py` | the simulators; `test_*.py`, `run_tests.sh`, `measure_*.py`, `profile*.py` the checks |
| `tools/bbcmem.py`, `extract_levels.py` | decoders for the BBC levels and tiles (level previews) |
