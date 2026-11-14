# Apple II / IIgs experiment handoff

## Direction and constraints

The long-term goal is a Codename Droid port for the Apple IIgs, which the user
owns. Eventually the platform-specific code should be separated into a HAL,
as in the user's other ports, but do not start a large HAL refactor or full
port yet. Work from first principles: small experiments, measurements, and
user feedback. The user considers the current scrolling speed acceptable
for this experiment.

**Do not run an emulator yourself.** The user will run and assess it.

The current experiment is for an enhanced Apple IIe in LinApple, not a IIgs.
LinApple does not emulate IIgs Super Hi-Res or the 65C816, so its performance
does not establish IIgs performance. The user has a Floppy Emu, but no IIgs
ROM dump or IIgs emulator installed yet; obtaining these is deferred.

## Current experiment

- `./run-apple2-experiment.sh` builds and launches the LinApple experiment;
  the user runs this. `LINAPPLE` is set in the local, untracked `tools.cfg` to
  `~/retro/emulators/linapple/build/linapple`.
- It loads `build/apple2/scroll.apl` directly through LinApple's program
  loader. This is not a bootable disk image. Do not use LinApple's `-a` option
  with this loader: it resets the CPU after loading the program.
- `hal/apple/ii/scroll.s` uses 6502 HGR monochrome, showing the top 192 scanlines
  of the original surface. Z/X or left/right arrow keys move the viewport
  one seven-pixel cell. It has no player, enemies, sound, smooth scrolling,
  or gameplay.
- The initial view is a full redraw. Scrolling shifts the existing screen and
  draws the exposed column; generated unrolled routines improve shift speed.
- `tools/make_apple2_experiment.py` generates glyph and world data from the
  BBC build and the C64 build's tile map and translation table. The other
  experiment files are `hal/apple/ii/scroll.cfg`, `hal/apple/ii/linapple.conf`,
  `tools/pack_apple2_experiment.py`, and `tools/test_apple2_experiment.py`.

## Measurements and verification

`make test-apple2-experiment` builds the program and checks every displayed
scanline at multiple positions, including viewport limits, and after scrolling
in both directions. Latest headless results:

- Full redraw: approximately 362,550 simulated cycles.
- Optimized shift: approximately 88,090 cycles in either direction.
- Previous shift implementation: approximately 162,000–178,000 cycles.
- Original full redraw: approximately 355,000 cycles; the user observed about
  half a second in LinApple.

The 6502 simulator's cycle counts are approximate; these figures do not
include player or enemy drawing and should not be treated as IIgs timings.
The user tested the earlier shift and requested roughly 3x more speed;
after the optimized shift was offered, the user said its speed was acceptable.
The optimized version passed the headless test but has not been independently
verified in the emulator by the assistant.

The existing `make test` suite passed before the latest shift optimization;
the latest focused Apple II test and `git diff --check` passed afterward.

## Repository state

At handoff, the last commit was `6adf828` (`Lift fix`). The Apple II work is
uncommitted: modified `Makefile`, `README.md`, and `tools.cfg.tmpl`; new
`hal/apple/ii/`, `run-apple2-experiment.sh`, and the three experiment tools listed
above. `build/` and local `tools.cfg` are not tracked. Preserve the user's
work; do not commit unless asked.

## IIgs toolchain work (2026-11-13)

- Assembler: the existing `~/retro/emulators/cc65` (ca65 reports "V2.18 - Git 555282497", the same
  commit as release 2.19). `.p816` works. Note `mvn` needs address operands (`mvn $e10000,$e10000`);
  `mvn $e1,$e1` silently assembles bank 0.
- Packaging: a custom boot block run from the Floppy Emu (3.5" 800 KB), not an S16/OMF app.
- `make apple2gs-boot` builds `build/apple2gs/droid-gs.po` from `hal/apple/gs/boot.s` (512-byte block 0,
  16 grey bars in Super Hi-Res). **Never run**: no IIgs emulator ROM and no hardware yet. Only block 0
  is filled; there is no ProDOS volume directory.
- Verified: NEWVIDEO `$C029` bits (firmware reference); SHR layout in bank $E1 (pixels `$2000`,
  160 bytes/line; SCB `$9D00`; palettes `$9E00`+n*$20) from GSplus `video.c`; block-driver convention
  (`$42`-`$47`) from the ProDOS 8 Technical Reference.
- Unverified: what the 3.5" firmware loads and jumps to for a custom boot block (block 0 at `$0800`,
  entry `$0801`, X = slot<<4 is implied by the hfs-boot source only), and bank restrictions of the
  block driver.
- GSplus is cloned and built at `~/retro/emulators/gsplus` (`build/gsplus`, target `gsplus-sdl`;
  the plain `all` target fails on macOS-only code). It needs a ROM (`ROM.03` or `ROM.01`), which the
  user will obtain later. The firmware reference and ProDOS 8 pages are in `~/retro/manuals/apple2/`.

### Super Hi-Res tile data (2026-11-13)

- `make apple2gs-tiles` (`tools/make_apple2gs_tiles.py`) converts the BBC tiles and level maps from
  `bbcmem` (the BBC source, not the C64 build) to `build/apple2gs/`: `cells.bin` (626 unique cells x 32
  bytes), `tiles.bin` (76 tiles x 16 u16 cell indices), `levels.bin` (12 levels x 64 columns x 8 rows),
  `palette.bin` (BBC black/red/cyan/white in entries 0-3).
- Geometry: each BBC pixel becomes two SHR 320-mode pixels, so a 4x8 BBC cell is 8x8 SHR pixels and the
  320x200 screen is the same 40x25 cell play area as the C64 port. The 626 cells need 16-bit indices
  (the IIe experiment fit 256 monochrome glyphs).
- `make test-apple2gs-tiles` round-trips every cell back to the BBC bytes and checks levels and palette.
  Not checked: how it looks (no emulator); the palette (BBC colours) is a choice, easy to change.

### Headless 65816 testing (2026-11-13)

- `tools/sim65816.py` is a headless 65C816 interpreter (all opcodes except BRK/COP/STP/WAI/WDM; decimal-mode
  arithmetic raises). Opcode names and addressing modes in `tools/op65816.py` come from GSplus's `instable.h`;
  `mvn` operand order (destination bank first) and its native-mode-only behaviour were checked there too.
  It counts instructions, not cycles, and does not model IIgs shadowing, interrupts, or emulation-mode
  direct-page and stack wrap quirks. Soft switches ($C000-$C0FF in banks 00/01/E0/E1) are plain bytes in `io`.
- `tools/asm65816.py` assembles snippets with the project's ca65 (`.smart +` tracks REP/SEP widths).
- `make test-apple2gs` runs `test_sim65816.py` (instruction semantics), `test_apple2gs_boot.py` (runs the real
  boot block from `$0801`, checks every pixel, SCB and palette entry in bank $E1, that nothing else changed,
  and `$C029` = `$C1` with the latch bit kept) and the tile round-trip. The boot test was shown to fail when
  the code is deliberately corrupted.
- The interpreter's own tests were written by the same author as the interpreter; its opcode table and `mvn`
  are checked against GSplus, other semantics (flags, stack, addressing) are from the 65816 reference as
  remembered. A real emulator run will be the independent check.

### Level view drawing (2026-11-13)

- `hal/apple/gs/draw.s` `draw_view` draws a 40 x 25 cell window of a level into SHR bank $E1 (call: native, 16-bit
  A/X/Y; A = level, `cam_x` 0-216, `cam_y` 0-7 in the direct-page variables). It is a loop over `draw_row`. It looks up level map -> tile ->
  cell index -> 32-byte cell and blits with unrolled 16-bit moves. Simple and correct first: 80,685 interpreter
  instructions (about 81 a cell) per full redraw. That is an instruction count, not a time; no IIgs cycle
  figure exists yet. A per-level flat cell-index map would remove most of the lookup work if it matters.
- `tools/test_apple2gs_draw.py` (in `make test-apple2gs`) runs it in the 65816 interpreter for five level/camera
  combinations and compares all 32,000 pixel bytes with a model built straight from the BBC data (bbcmem), so
  BBC tiles -> converted tables -> 65816 routine -> pixels is checked end to end, and that nothing outside the
  pixel area is written and the data bank is restored.
- `hal/apple/gs/draw_test.cfg` is only the test link layout (data in banks 2-3, loaded by the test). The real memory
  map and loader are undecided.
- Lesson: ca65 assumes 8-bit registers at the start of a routine unless told; it needs `.a16`/`.i16` in a routine
  entered in 16-bit mode (without it `and #3` assembled as 2 bytes and the interpreter, correctly, desynchronised).

### Scrolling (2026-11-13)

- `scroll_right/left/down/up` in `hal/apple/gs/draw.s`: move the camera one cell, shift the existing screen with one
  block move (`mvn` for right/down, `mvp` for left/up) and draw only the exposed column (`draw_column`) or row
  (`draw_row`). Horizontal: the whole 32,000-byte screen shifts 4 bytes, the bytes that wrap between lines land
  in the exposed column and are drawn over. Vertical: shift 1,280 bytes. At a camera limit the routine returns
  carry set and does nothing. `draw_view` must run first (it sets the level).
- Per scroll in the interpreter: about 2,000 instructions (horizontal) or 3,200 (vertical) plus one block move of
  31,996 or 30,720 bytes. The block move dominates and I have no verified IIgs cycle figure for it (GSplus's
  source only has its own relative accounting), so there is no time estimate; the real number needs the
  hardware or an emulator. A full redraw is about 80,700 instructions, so scrolling is far cheaper in
  instructions but is bound by moving 32 KB.
- The test (`test_apple2gs_draw.py`) runs four scenarios (including both camera limits and refused scrolls) and
  compares the whole screen to the full-redraw model after every single scroll, plus no writes outside the
  pixel area. Deliberately breaking `scroll_left` was caught at once.
- The interpreter now counts a block move as one instruction and keeps bytes moved in `moved`.

### Feasibility spike: the C64 game logic on a 65816 (2026-11-13)

`make spike-iigs` (needs `build/c64/game.prg`; the C64 sources are unchanged, nothing refactored). Scripts:
`tools/spike_iigs_coupling.py` (static) and `tools/spike_iigs_diff.py` (dynamic).

**Result: the game logic runs unchanged on a 65816, and its coupling to the C64 is small.**

- *Differential run.* The unchanged `game.prg` runs on two independent CPU models, `tools/sim6502.py` (NMOS 6502, as
  the project's tests use it) and `tools/sim65816.py` in emulation mode (direct page 0, data bank 0). From one
  starting state both run `set_level` and then `game_step` with random keys (lives topped up, `wait_frames` made
  to return, since no interrupt runs here). All RAM except `$D000-$DFFF` and `$00/$01` must match after every call:
  6 levels x 400 steps, seeds 2, 3 and 4 (16 million instructions each), identical. A lift ride on level 11
  stops that level's run (it waits for the raster); that is display code. This also cross-checks the new
  interpreter against an independent one. The first mismatches were harness artifacts (the C64 charset at
  `$C000` hits the interpreter's IIgs soft-switch window; the interpreter lacked the 6502 zero-page wrap in
  emulation mode, now added and unit-tested).
- *Split banks.* `--split` runs the code from bank 0 but sends every absolute-addressed data access to a copy of
  RAM in bank 1 (DBR = 1; direct page and stack stay in bank 0). It also matches, which would give the logic a
  full 64 KB data bank (the C64 layout nearly fills 64 KB: about 20 KB code, 14 KB read-only data, ROWS 8 KB,
  BPAT 2 KB, level maps 3.5 KB). Requirement: no self-modifying code. The only instance found is in the SID
  driver, `snd_osword` (`stx @blk+1`, `sty @blk+2`), which the IIgs sound replacement removes anyway; it is
  stubbed in the split run. Not tested: relinking with data in a separate bank (ld65 would need the data segments
  placed at bank-1 offsets with a loader that copies them); only the principle is shown.
- *Coupling (static scan).* Logic files `player enemy objects blaster events level` are 5,000 lines. Their calls
  into non-logic code are about 22 routines: the sound effects (`sfx_*`, `play_sound_for_damage`), the full-screen
  modes (`wrist_terminal`, `jet_pack_screen`, `pause`, `game_over`, `game_completed`), the lift (`lift_ride_scroll`,
  `lift_finish_view`), `save_game`, `cheat_keys`, and `init_view`/`make_sprites`. Only `level.s` touches hardware
  directly (7 lines): `intern`, which creates a character from 8 BBC bytes, converts it through `conv_table` into
  the C64 charset (with `$01` bank switching for the staging area). That store is the one data-path boundary:
  the logic keeps the BBC bytes in `BPAT` for its own collision tests, so it needs the C64 charset only for display.
- *Display budget.* `MAXCH` is 204, so a level uses at most about 256 characters at once: a per-level table of 256
  SHR cells (8 KB) replaces the C64 charset; `intern`'s store would write the 32-byte SHR cell instead.
- *What this does not show.* Timing on a real IIgs; the display side (sprites, pixel scroll, matrices) which is the
  platform code; the lifts and full-screen modes; sound (SID driver replaced by an Ensoniq one).

### The C64 logic drives a Super Hi-Res screen (2026-11-13)

`hal/apple/gs/shr.s` (prototype display layer) + `tools/test_iigs_display.py` (in `make spike-iigs`). The game logic
is the unchanged C64 build running in emulation mode in bank 0, laid out as on the C64; the layer is native code
in bank 2, called with `JSL shr_present`, which switches to native mode and back.

- **What it does.** The logic keeps each character as 8 BBC bytes in `BPAT` and a 40 x 25 matrix of character
  numbers. `shr_present` compares `BPAT` with a shadow copy, reconverts every changed character into a table of
  256 SHR cells (32 bytes each, through the 1 KB `bbc2shr.bin`), then blits the shown matrix (`MAT_A`/`MAT_B` by
  `cur_buf`) to bank $E1. Its own state is a direct page at `$0700` (unused in the C64 layout; asserted free).
- **Why a shadow compare.** The logic rewrites characters in place during play (`enemy.s` calls `set_char` for the
  enemy pool), so polling `nchars` is not enough; the first version missed this and the test caught it. The proper
  design is a hook in `set_char`/`intern` per changed character, which would remove the scan.
- **Test, exact.** With `place_objects` and `init_enemies` made to return, all 12 levels: the screen built by
  logic -> layer -> pixels equals, byte for byte (32,000), a picture drawn from the BBC's own tile art
  (`bbcmem.tile_cell_column`) using the game's level map and `level_xlat`. This checks `intern`, `fill_rows`, the
  matrices and the layer against the original art. **Test, play:** with enemies and objects, 60 `game_step`s on
  five levels; every presented screen equals a model from the logic's own matrix and `BPAT`, every converted
  character equals the full conversion, nothing is written outside the pixel area or the layer's page.
- **Cost.** `shr_present` is about 57,500 interpreter instructions (more when characters change). That is an
  instruction count, not a time. Most of it is the 1,000-cell blit and the 1,024-word shadow compare. Unoptimised.
- **Not in it yet:** the fine scroll (`t_xs`, 0-7 C64 pixels = 0-3 BBC pixels, so 0-3 bytes), the player's and
  blasters' sprites, the lifts and full-screen modes, sound, real hardware boot.
- **Harness gaps found (fixed).** The harness never ran the game's `start`, which fills `MIRROR_TABLE` at `$0600`
  (mirrored tiles came out blank); it is now reproduced from `src/game.s` in `test_iigs_display.py` and the spike
  (the earlier spike results stand: both CPUs had the same table, zeros). The interpreter's IIgs soft-switch
  window at `$C000-$C0FF` is switched off there, since the C64 charset lives at `$C000`.
- **Data findings.** (1) `bbcmem.translation()` gives level 0 with the spaceship's four tiles already turned into
  walls and rope; the game starts with the ship (the C64's `level_xlat` row 0: `.. 35 34 .. 36 37`).
  `make_apple2gs_tiles.level_tiles` patches that for level 0; `bbcmem` itself is unchanged. (2) The game's level
  maps are not the raw disc data: `make_data.py` removes the lifts and applies `initialise_levels` patches, and pads
  the unused half of levels 7 and 11. So **`levels.bin` and the tile-based `draw_view`/scroll routines of the earlier
  experiment do not match the game's maps (lifts) and are superseded** by the logic-driven path (the logic builds
  the world; the layer only draws the matrix). `cells.bin`/`tiles.bin` are still valid art.

### Running in GSplus (2026-11-13)

- The user's ROM: `~/Downloads/Apple IIGS ROM 01 - 342-0077-B.bin` (128 KB, left untouched). It has **bank $FF first and
  bank $FE second** (the reset vector `$FA62` is at file offset `$FFFC`; the second half starts with bank-$FE code). GSplus
  reads a 128 KB file straight onto banks $FE-$FF, so the halves are swapped into `~/retro/emulators/gsplus/ROM.01`
  (sha1 `e4fc7560b69d062cb2da5b1ffbe11cd1ca03cc37`; reset vector `$FA62` at `$1FFFC`). This matches the KEGS note that the
  27C1001 dump of this chip is not in the layout KEGS expects. GSplus only checks the size, so a wrongly laid out ROM
  fails at boot, not at load.
- `./run-apple2gs.sh` builds `build/apple2gs/droid-gs.po` and starts GSplus with `-rom`, a private `-cfg`
  (`build/apple2gs/config.kegs`) and the image as `-s5d1` (3.5" drive, slot 5). Extra arguments pass through to GSplus.
  `GSPLUS` / `GSPLUS_ROM` can be set in `tools.cfg`. The script was written, not run: the user runs the emulator.
  It shows the 16 grey bars if the boot block works; it has never been run on any IIgs or emulator.

### First emulator run (2026-11-13, user's screenshot)

`./run-apple2gs.sh` in GSplus 1.38 with the user's ROM 01 (halves swapped, see above): **the boot block works.** The
16 grey bars appear in Super Hi-Res (blue default border). The log shows the real ROM tried slot 7 (no drive), then
"trying slot 5!", and booted the `.po` image from the 3.5" drive. This confirms, in GSplus running real ROM 01 firmware:
block 0 is loaded at `$0800` and entered at `$0801` in emulation mode with only the `$01` ID byte as a signature; the
`clc/xce` + `rep` switch, bank $E1 stores, `mvn` fill and the `$C029` read-modify-write behave as `test_apple2gs_boot.py`
predicts. Still untested: real hardware / Floppy Emu, ROM 03, loading more than block 0 (the multi-block loader is the
next boot-path question), the user's mention that nothing else is on the disk (no ProDOS volume directory).

### Two-stage loader and level demo (2026-11-13)

`./run-apple2gs.sh` now boots the loader demo (`droid-gs.po`); `./run-apple2gs.sh bars` runs the earlier grey-bar test
(`bars.s`, `bars.po`). **Not yet run in an emulator or on hardware: the user runs it.** A red border means a failed read.

- **Stage 0** (`hal/apple/gs/boot.s`, the 512-byte block 0): checks the slot's SmartPort signature bytes, finds the dispatch
  address (`$Cs00 + [$CsFF] + 3`), reads blocks 1-8 to `$0A00` with standard ReadBlock calls, hands the dispatch address
  to stage 1 at `$19F0` and jumps. The call convention is from the hfs-boot source (a working IIgs loader) and the
  Firmware Reference ch. 7 (`~/retro/manuals/apple2/`): emulation mode, D = 0, DBR = 0, `JSR dispatch / DFB 1 / DW list`,
  list `{3, unit 1, buffer word (bank 0), block 3 bytes}`, carry clear on success, return at JSR + 3. Extended calls
  (`$41`, 32-bit buffer) exist but depend on the slot's ID byte; standard calls and a bounce buffer are used instead.
- **Stage 1** (`hal/apple/gs/stage1.s`, 196 bytes): reads the load table (`tools/make_apple2gs_disk.py` makes it:
  disk block, block count, address, bank per payload), reads each block into `BOUNCE` ($1A00) through SmartPort
  (switching to emulation mode and back around each call), copies it with `mvn` (destination bank patched into the
  instruction; ca65's `mvn` operands are (source, destination) and encode the destination bank first), then jumps to
  the demo in native mode. An entry that would cross a bank, or a failed read, shows a red border and stops.
- **Memory map** (`loader.inc`): boot block `$0800`, stage 1 `$0A00-$19EF`, `SPENTRY $19F0`, bounce buffer `$1A00`,
  palette `$1C00`, demo + `draw.s` `$2000`; cells, tiles, levels in banks 2 and 3 (as `draw_test.cfg`).
- **The demo** (`hal/apple/gs/demo.s`): palette and scan-line bytes to bank $E1, `draw_view` of level 0 (tile-based
  routines of the earlier experiment, so no lift pieces: a look at the art and a test of the loader, not the game),
  keys scroll it (Z/X, K/M or arrows) using the tested scroll routines.
- **Test** (`tools/test_apple2gs_loader.py`, in `make test-apple2gs`): boots the image in the interpreter with a
  model of the slot-5 SmartPort that asserts the documented constraints (emulation mode, D = 0, DBR = 0, valid list,
  buffer outside zero page) and serves blocks from the image. Checks: 68 blocks read in order; every payload intact
  at its address; memory outside the payloads untouched (junk-filled banks); the level drawn exactly as the tile
  model says; 17 keys each leave the screen equal to the level at the camera; read failures and a missing signature
  turn the border red and stop. Deliberately breaking the loader (destination advance 511) was caught.
- **Limits.** The firmware model is my reading of the documents; the grey-bar run confirmed only the block-0 entry.
  Unknown until run: whether GSplus's slot-5 SmartPort accepts the call as modelled, ROM 03, hardware/Floppy Emu.
  Payloads are capped at one bank each and total 800 KB; the unit is hard-coded to 1.

### Loader confirmed in GSplus; levels.bin from the game's data (2026-11-13, user's second screenshot)

- **The loader works in GSplus** (`./run-apple2gs.sh`): stage 0 found the slot-5 SmartPort, stage 1 read 68 blocks and copied
  the payloads into banks 0, 2 and 3, and the demo drew a level. The screenshot is pixel-identical to the headless render of
  the same image (`tools/test_apple2gs_loader.py`'s machine), so the SmartPort model matched GSplus's ROM 01 on every call.
- **Correction to my first reading of that picture.** It showed stacked ship-like pieces down the left edge. I guessed the
  level maps were wrong; they were not: that is what the game's own level-0 data holds at its far left (camera 0,0),
  also seen in the logic-driven bare test. A new game actually starts the camera at (179, 0), under the ship
  (`new_game` -> `init_view`), so the demo now starts there and shows the surface and the spaceship like the C64 screenshot.
- `levels.bin` is now made from the C64 build's `level_tiles0` and `level_xlat` (`make_apple2gs_tiles.level_tiles(level)`,
  needs `build/c64/game.prg`), the game's maps with the BBC's startup edits (lifts, initial tiles), not the raw disc data.
  This changes levels 1, 2, 5 and 6 (lift pieces); level 0's picture was already the same.
- Test: 67 keys in the demo (letters, lower case, arrows, an ignored key, into the right and bottom limits) each leave the
  screen equal to the level at the camera.

### Scrolling feedback and fixes (2026-11-13, user: "scrolling looks OK, auto repeat delay, flickering at the edge")

- **Auto-repeat delay.** That is the keyboard's repeat (in GSplus it is emulated: `adb.c`). `$C010` returns "a key is still
  down" in bit 7 (GSplus `adb_access_c010`: `g_hard_key_down << 7`; the real ADB keyboard's flag), so the demo's key loop now
  repeats the last key at once while it is held, with no delay (`demo.s` `wait_key`/`held`). A new press replaces the held key.
  Possible oddity, unchecked: if the flag also counts modifier keys, holding Shift after tapping a scroll key would keep scrolling.
- **Flicker at the edge (my diagnosis, not yet confirmed on screen).** The old horizontal scroll moved the whole screen
  4 bytes in one block move and only then drew the exposed column, so for the whole move the edge column held the bytes
  that wrap from the next line. Now `scroll_left`/`scroll_right` go line by line: shift the line (`mvn`/`mvp`, 156 bytes)
  and write its 4 new edge bytes at once (`prepare_column` makes the 25 cell offsets first). `test_apple2gs_draw.py`
  asserts that during every scroll each of the 32,000 pixel bytes is written exactly once (no transient state), and the
  screen still equals the full redraw after every step. Cost: about 8,000-9,000 instructions plus 200 block moves per
  horizontal scroll instead of about 2,000 plus one.
- **What is not fixed.** Tearing: the update still takes much longer than a video frame (31 KB of moves) and nothing
  waits for the vertical blank or double-buffers (`$C019` bit 7 is 0 during blank), so a seam sweeps down the screen while
  scrolling. Vertical scroll still shifts the whole screen, then draws the new row. A real fix needs less data moved per
  step (e.g. scroll in steps, redraw only what changed) or beam-synchronised drawing; no IIgs timing has been measured.

### Stuck scrolling the old direction (2026-11-13, user: "sometimes it gets stuck scrolling left when pressing right")

- **Cause (found in GSplus `adb.c`, reproduced in the test).** The keyboard has a queue of 8 key events (`MAX_KBD_BUF`), and
  every read of `$C010` moves it on by one, even with no strobe set. While a key is held, auto-repeat events (every 3 frames)
  queue behind slow scrolls (each takes far longer than the repeat interval), so a newly pressed key waited behind up to 7
  stale repeats of the old one and the old direction kept scrolling until they drained. My first hold logic handled one event
  per pass.
- **Fix** (`demo.s` `wait_key`): each pass reads every waiting key and keeps only the newest (`new`/`bmi new`), then reads
  `$C010` only after the queue is empty (bit 7 = a key is still down); a tap that ends before we look still scrolls once
  (`fresh`). Left over after a release: at most one extra scroll from a queued repeat.
- **Test.** `test_apple2gs_loader.py` models the queue (`$C000` = head of queue, each `$C010` read pops one, a key counts as
  down until N scrolls have started): 25 cases including seven stale left-repeats then a right press, which must give only right
  scrolls. With the drain removed the test fails (extra old-direction scrolls), so it does reproduce the report.
- Whether the real keyboard queues the same way is unknown; the demo behaves correctly either way since it only relies on
  "newest key wins" and "bit 7 of `$C010` = a key is down".

### Milestone 1: the C64 logic playing on the IIgs, no sprites (2026-11-13) — `./run-apple2gs.sh`

**Not yet run in an emulator or on hardware (the user runs it).** The demo scroller is now `./run-apple2gs.sh demo`,
the grey bars `./run-apple2gs.sh bars`. Disks: `build/apple2gs/game/droid-gs.po`, `demo/demo.po`, `bars.po`.

- **Architecture: bank 2 is the C64's RAM.** `build/c64/game.prg` (patched, 3 places, all asserted by symbol in
  `tools/make_apple2gs_disk.py`) loads into bank 2 at `$0801`. The C64 logic runs there in emulation mode with PBR = DBR = 2,
  D = 0 (zero page and stack in bank 0). Everything it addresses, including the C64's RAM under I/O and ROM at `$A000-$FFFF`
  (ROWS, charset, matrices, BPAT), is plain RAM, so no relink is needed and self-modifying code works. (The earlier spike's
  "code in bank 0, data in bank 1" would have put the charset and matrices on the IIgs's `$C000-$CFFF` I/O and slot-ROM space.)
- **Platform** (`hal/apple/gs/platform.s`, bank 0 `$2000`; display layer `hal.s` linked with it, `-D LOGIC=$020000`): sets up
  Super Hi-Res, zeroes the layer's tables (bank 3) and the C64's BSS, makes the mirror table `start` makes, sets
  `rows_page`/`add`/`c64_pal`, calls `clear_buffers`, `copy_sprites`, `new_game` (through `tramp.s`, 16-byte JSL trampolines in
  bank 2 `$0700` that set DBR = 2), then each frame: wait for vertical blank (`$C019` bit 7 = 0), read keys, `tick += 1`,
  `dt = 1`, the logic's `compute_frame`, `ready = 0`, `shr_present`. One frame per loop at best, so on a machine too slow
  for 60 Hz the game simply runs slower than real time (steps come every 5 loop passes: 12.5 a second at 60 Hz).
- **Keys.** The logic's `read_keys` is kept; its CIA row read (`lda $dc01`) is patched to `lda KEYROWS,x`, a 60-byte table in bank
  2 that the platform fills. One ordinary key at a time (the IIgs keyboard register shows only the newest; newest-key-wins queue
  drain and `$C010` bit 7 as in the demo) plus Open Apple = jump, Closed Apple/Option = fire (`$C025` bits 7/6), so jump or fire
  can combine with a direction. Map: X/right arrow, Z/left arrow, `;`/up arrow, `/`/down arrow, A, J, RETURN (jump), `=` (fire),
  ESC, P/DEL (pause), D, TAB, O, SPACE, S, B, M. Real multi-key input (the ADB keyboard's key-up/down) is not done; a joystick
  would be the other route. Unknown: how GSplus maps the host's Alt/Meta keys to the Apple keys.
- **Waits.** `wait_frames` and `frame_wait` (which spin on the C64's interrupt-driven `tick`) are patched to `JSL
  plat_wait_frames`/`plat_frame`: a vertical-blank wait, `tick += 1`, and show a staged picture if `ready`. Not handled: loops
  that spin on `ready` (the lifts, some screens): they need a real vertical-blank interrupt or more patches. The title and intro
  are skipped (the game starts with `new_game`). Sound calls run into the C64's SID registers, which are plain RAM here.
- **Test** (`tools/test_apple2gs_game.py`, in `make test-apple2gs`, uses the shared machine model `tools/iigs_machine.py`): boots
  the game disk through the SmartPort model; checks the new game, mirror table, patches, trampolines; every picture equals a
  model of the logic's matrix and BPAT; 60 idle frames give tick +60, 12 game steps (the BBC rate) and no movement; all 22
  keys (both cases, arrows, RETURN, ESC...) arrive as the logic's `K_*` key numbers (through the platform reader and the logic's
  `read_keys`, not full frames, since A/J/P/ESC open modal screens); Open/Closed Apple combine with X in pressing order; X, Z and
  X + Open Apple (jump) move the player as expected; the patched waits pass frames.
- **Logic quirk seen, not a bug of ours:** `read_keys` drops released keys from its pressing-order list one per call, so
  `key1`/`key2` take up to three reads to clear while `keys` clears at once.
- **Next:** software sprites for the player and blasters; the game's speed on a real 2.8 MHz IIgs is still unmeasured (GSplus can
  limit its speed); then lifts, the full-screen modes, a title, and the key-input question.

### Speed: the display layer is now incremental (2026-11-13, user: "no player drawn, and the scrolling is now very slow")

- **No player is expected**: sprites are the next piece.
- **Measured cause (interpreter instruction counts, not time).** Walking right, 87% of all instructions were in `shr_present`,
  about 65,000 per frame: it compared and reconverted all characters and redrew all 1,000 cells every frame.
- **Now** (`hal.s`): `shr_init` (called once by the platform) zeroes the tables; `shr_present` keeps a shadow of the matrix
  (`shadowmat`) and a table of each cell's screen offset (`cellscr`) and redraws only cells whose character differs from the
  shadow or whose character's pixels changed (the dirty flags, kept until the cells are drawn). When the logic's window moves by
  one cell the screen is shifted with block moves (horizontal: line by line with the new edge written at once; vertical: line
  blocks, new row left to the cell pass) and the shadow shifts with it; any other jump (or the first picture) redraws everything.
  Per call, in instructions: idle 8,800 (was 57,500; mostly the BPAT change scan), shift one cell horizontally 26,000,
  vertically 19,000, a jump or first picture 71,000. Walking right: per frame min 13,900, average 35,400, max 69,500 (was ~65,500
  average). `test_iigs_display.py` checks every present equals the model, including the four shift directions, a jump and two
  steps at once, and the bare picture of all 12 levels still equals the BBC tile art exactly.
- **Not solved, and not measurable here:** time. Instruction counts are not cycles. Super Hi-Res memory (banks $E0/$E1) is
  the IIgs's slow RAM, believed to run at 1 MHz regardless of the CPU speed (general IIgs knowledge, NOT verified in this
  project or in GSplus's source), so a one-cell scroll that moves 31,000 bytes there would cost tens of milliseconds even on a
  fast CPU, and a full redraw more. GSplus's status line shows "Limit" and "Eff MHz"; its Speed setting (config variable `Speed`:
  0 unlimited, 1 1 MHz, 2 2.8 MHz, 3 8 MHz Zip, plus "ZipGS Speed") decides the emulated CPU speed. The first run showed
  Limit 16.0 MHz, so the user's runs have probably been emulating an accelerated machine.
- **Remaining ideas if it is still slow:** hook `set_char`/`intern` instead of scanning BPAT (removes most of the 8,800), shift the
  shadow with one block move, keep the picture in fast RAM and copy only changed regions to $E1, scroll in larger steps than one
  cell, or move less per step.

### Speed gauge (2026-11-13)

User: GSplus status line "Eff 16.33, Limit 16". Meaning: Limit is the emulated CPU speed (a 16 MHz accelerated IIgs, the Speed
setting), Eff is what GSplus achieves; Eff >= Limit means the host keeps up, so the game is slow *on a 16 MHz IIgs*, i.e. our code's
cost is the cause (Eff also counts time spent waiting for the next video frame, so it says nothing about headroom).
The platform's main loop now sets the border colour as a gauge: black while waiting for the next video frame, red while the logic
runs (keys, `compute_frame`), green while `shr_present` draws. If the border is never black, a frame takes longer than 1/60 s and
the game runs slower than real time; how much of the border is red vs green says where the time goes. (Debug aid; remove later.)

### Camera: zone-based instead of continuous (2026-11-13, user's gauge: "green top and bottom, tiny red, flickers green at scroll")

- **Reading of the gauge.** Green (drawing) dominates, red (game logic) is small, and the green gets long when the screen scrolls:
  every one-cell scroll moves about 31,000 bytes of Super Hi-Res memory (believed slow, ~1 MHz; unverified), and the C64's
  continuous follow does that nearly every step.
- **Change.** `calc_scroll` is patched (JSL `plat_calc_scroll`, `platform.s`): the window (columns w .. w + 39) holds still while
  the player is within w + 10 .. w + 29, jumps to w = px - 10 on leaving to the right, w = px - 29 on leaving to the left,
  centres (w = px - 17, the C64's offset) when the player is off the window (new level, lift), and stays within 0 .. 216. It sets
  `t_w`, `t_xs` (= 0: no fine scroll), `spx` (the window's left edge in C64 pixels, which the sprites are placed by) and `spos`.
  The logic's enemy and blaster culling reads `t_w`, which stays consistent with the window shown. One scroll now costs the same
  as before but happens about once per 19 columns walked. The logic's `matrix_update` sees a multi-column change and redraws the
  matrix at once; the display layer sees it as a jump and redraws all cells (about 71,000 instructions, about 32 KB written).
- **Test** (`test_apple2gs_game.py`): the patch bytes; 15 cases (inside, each exit, off-window, both clamps) for the window, `t_xs`,
  `spx`, `spos`; walking right for 120 frames moves the window once, by several columns, and the player ends inside the zone; the
  picture equals the matrix throughout. The case table mirrors the rules as I wrote them, so it checks the arithmetic, not the
  design.
- **Costs and risks.** Vertical scrolling is unchanged (still the logic's one-row follow). Climbing, lifts and screens that rely on
  the window moving smoothly are untested. The jump scroll still takes more than one video frame; whether that is acceptable is for
  the user to judge by the border gauge (green stretch) and feel.

### Camera reverted to the C64's continuous follow (2026-11-13, user: "jumping 19 columns makes no sense ... that's nearly the whole screen")

The zone camera above was the wrong call: a 19-column jump is a page flip, not scrolling, and it dodged the cost instead of reducing
it. The build default is again the C64's own `calc_scroll` (the window creeps a column at a time, the player ~17 columns from the
left edge). The zone camera stays as `make apple2gs-boot CAMERA=zone` (`plat_calc_scroll`, still unit-tested), but is not the default.
With the incremental display layer, one-cell scrolling costs what the demo's scrolling did, which the user found acceptable
("scrolling speed is better"). Not yet seen in an emulator in this form: the user to judge speed with the border gauge.
Note for the sprites: the C64 camera has a fine offset `t_xs` (0-7 pixels) that the display layer ignores (the matrix is drawn
in whole cells), so sprites must be placed against `t_w * 8`, not the C64's pixel-exact `spx`.

### Software sprites: the player and the blasters (2026-11-13)

- **What is drawn.** The logic stages up to 8 C64 hardware sprites each frame (`make_sprites` inside `compute_frame`): `p_sx`, `p_sy`,
  `p_ptr`, `p_msb`, `p_en` (26 contiguous bytes). `shr_present` now draws them in software over the cells, sprite 7 first so that
  sprite 0 is in front (the C64's priority). Sprite k is at screen (`p_sx` + bit 8 of `p_msb`, - 24 - `t_xs`, `p_sy` - 50); its
  image is 21 lines of 3 bytes at `SPRAREA` + `p_ptr` * 64, four two-bit pixels a byte, 0 transparent, 1/2/3 = BBC colours 1/2/3
  (the same indices as the tiles; sim_check's renderer agrees); one sprite pixel = two Super Hi-Res pixels = one byte, which
  needs every sprite x even: true in all 340 test frames (asserted in the model) because positions are multiples of 2 C64 pixels
  and `t_xs` is subtracted. The player is two sprites (three crawling), the blasters are 3-7.
- **Erase.** The cells a sprite covered are kept (`splist`, up to 256) and redrawn from the shadow matrix before anything changes
  (before any scroll shift too, so old pixels are never carried along); then all sprites are drawn and their cells noted. If the
  registers (`spstate`, 26 bytes + `t_xs`) are unchanged, the window did not move, and no cell was drawn this frame, nothing is
  done: the sprites are still on screen. A window move always counts as a change (found by a test where the window moved but the
  registers did not: the old pixels shifted with the background and left a ghost).
- **Tests.** `tools/iigs_model.py` builds the reference picture independently (matrix + BPAT + sprites from the logic's registers
  and image data); `test_iigs_display.py` (random play on five levels, the four shift directions, jumps) and `test_apple2gs_game.py`
  compare every presented frame with it. The game test plays a script (walk both ways, jump right, fire, walk and fire, kneel,
  press down again to crawl, crawl both ways, stand, walk) and checks each of 340 frames: no ghosts or leftovers; blaster sprites
  appeared on 10 frames and the crawling third sprite on 91.
- **Cost.** Sprite pixels are written one byte at a time, only the non-transparent ones (about 3,000 instructions per 21 x 12
  sprite); the erase redraws every cell the sprites touch (up to about 40 for the player). A frame where a sprite changes costs
  roughly 25,000-35,000 instructions in `shr_present` (idle with nothing changed: 8,900). Instruction counts, not time.
- **Not done / unknown:** the sprites erase and redraw every frame they move, so they may flicker where the beam passes; no
  double buffer. Sprites in the lifts and full-screen modes are not handled. How the game feels at speed is not yet known.

### Speed result, keys, lifts, title and the screens (2026-11-14)

- **Speed (parked by the user).** GSplus does not charge extra time for the slow memory of banks E0/E1 (`moremem.c` maps them as
  plain pages; only I/O and ROM pages get wait states), so a fast-RAM picture buffer cannot be measured there, and my interpreter
  has no cycle model. At `-g_limit_speed 2` (2.8 MHz) the user saw the border all green (drawing) with red at the bottom: far too
  slow; at 16 MHz it was green-dominated too (so the cost is CPU time in the copy loops: `mvn` is 7 cycles a byte and a one-cell
  shift moves about 31,000 bytes). Ideas for later: a stack-slam copy (`PEI`, 3 cycles a byte) with the stack in bank 1 shadowed
  to E1 via RAMWRT; a rolling-offset picture buffer so nothing is shifted inside it. Not started.
- **Keys.** ADB gives one "hard" key at a time (`$C000`/`$C010`) plus the modifiers in `$C025`. So walking + jump works only if
  jump is a modifier: Open Apple (the host's Super key, which a desktop may grab) or now **Shift** too (the keymap has `:` and `?`
  for up and down with Shift held). Fire is Option/Closed Apple.
- **The waits for the interrupt.** Five places in the logic spin on `ready` (main, the lift ride x3, game over): the packer finds
  `LDA ready / BNE *-3` by byte pattern (asserting exactly five) and makes each a `JSL plat_frame` + NOP. `plat_frame` now also
  reads the keyboard (the modal screens poll keys inside the logic; it switches the data bank to 0 for `read_host_keys`, whose key
  table is in bank 0 - found by the title test) and shows the matrix every frame, since the VIC-II reads the matrix live; the
  sprite registers are taken over only when `ready` is set, as the C64 interrupt does: `shr_present` latches the 26 bytes into
  `splatch`, `shr_present_hold` shows the matrix with the old latch.
- **VIC writes.** `screen_off`/`screen_on` are patched to RTS and the lift's `STA $D015` to NOPs (bank 2 `$D000` is the sprite blocks).
  Sound writes only happen in `snd_frame` (the interrupt), which does not run: the game is silent.
- **Title and restart.** The title screen is character-based like the rest, so the platform runs it (`TR_TITLE`) before `new_game`
  (and `TR_JUMP_SAVED` if J chose the saved place); `restart_game` (after game over) is patched to `JML plat_restart`, which resets the
  stack and runs the same sequence.
- **Tests.** `test_apple2gs_game.py` now boots through the title (SPACE), plays the lift ride level 0 -> 1 (17 pictures, last equals
  the matrix), the wrist terminal with its map, and game over -> title -> new game. `test_iigs_display.py` makes the logic's
  `ready` spins fall through.

### Speed-ups, round 1 (2026-11-14)

`tools/sim65816.py` now keeps an ESTIMATED cycle count (`cycles_estimate`: the WDC table as I know it; no slow-RAM waits; not checked
against hardware). `test_iigs_display.py` prints it per `shr_present` case (2.8 MHz frame = 47,000 cycles; 16 MHz = 267,000):

| case | before | now |
|---|---|---|
| idle present | 40,800 | 10,600 |
| one-cell shift, horizontal | 367,000 | 285,000 |
| one-cell shift, vertical | 344,000 | 271,000 |

- `set_char`/`intern` are patched (`tools/iigs_patch.py`, in the packer and the display test) to `JSL shr_char_hook`, which compares
  the character's 8 bytes with `shadow` and flags it; the 2,048-byte BPAT scan is gone. `convert_char` keeps `shadow` current;
  `shr_init` marks all 256 characters dirty.
- The matrix compare is unrolled (long addressing, two copies for MAT_A/MAT_B).
- Horizontal shifts: 16-bit unrolled copy of each line (`shl_line`/`shr_line`, 6 cycles a byte against `mvn`'s 7), the new column built
  once into `edgebuf`. Vertical: `shu_line`/`shd_line`. Shadow shifts by `mvn`/`mvp` (a block move leaves DBR at its destination bank:
  `set_bank_e1` after each).
- Sprites are composed off-screen (`shrbuf`, 32,000 bytes of bank 3) and each affected cell written once (see the flicker work).
- What is left in a shift: ~190,000 cycles of pure copying (31,000 bytes at 6 a byte). Below that needs a different copy: stack slam
  (`PEI`, 3 a byte, stack in bank 1 shadowed to E1 via RAMWRT - not verified), or fewer bytes (DHGR/HGR, smaller window).

### Stack slam and the screen in bank 1 (2026-11-14, user: real machine is stock 2.8 MHz; "do the stack slam")

Sources checked: Apple IIgs Technical Note #70 (apple2.gs/technotes/tn-iigs-070: stack to bank 1 with `$C005`, bank 1 shadowed to
$E1 by clearing bit 3 of `$C035`; no firmware/toolbox/OS calls while it is there), Eric Shepherd's KansasFest 2004 Wolfenstein 3D
talk (PEI slamming) and the iigs-game-engine `PEISlammer.s` (RAMRD+RAMWRT so PEI reads bank 1 too; interrupts off), GSplus
`moremem.c` `fixup_ramwrt` (models exactly this; power-on `$C035` is `$08`, i.e. SHR shadowing OFF - `shr_init` clears bit 3).
- **The screen is bank 1 `$2000-$9CFF`** (fast RAM): every data-bank-`$E1` store/load in `hal.s` is now bank 1 (`set_bank_e1` is
  `pea $0101`); writes are mirrored to `$E1` by the shadowing, reads never touch slow memory. (`platform.s` still writes the
  palettes and SCBs to `$E1` directly.)
- **`slam_right` / `slam_down`** (segment SLAM, `slam.bin` loaded at 03:E400 - outside bank 0 because with RAMRD set, instruction
  fetches from bank 0 `$0200-$BFFF` would read bank 1): interrupts off, S and D saved, RAMRD+RAMWRT on, D = the line, S = its end,
  78 (80) `PEI`s, restored. They move data to HIGHER addresses in place (pushes go down), so only the picture moving right and down
  can use them; left and up still use the unrolled copy (now reading bank 1).
- `tools/sim65816.py` models RAMRD/RAMWRT and the bank-1 -> `$E1` shadowing (opt-in via the softswitch writes; the display test
  disables the I/O window, so bank `$E0` softswitches are handled there too). ca65 will not assemble `pei (expr)`: raw `$D4,n`.
- Estimated cycles (2.8 MHz frame = 47,000): picture moving right 284K -> 179K, moving down 271K -> 175K (the sim's PEI is 6; with
  a direct page not on a page boundary it is 7); left/up unchanged at ~285K/271K. A frame with nothing moving: 10.6K.
- NOT verified on hardware: the slam relies on TN #70. If the real machine shows a corrupt picture after scrolling, that is where to look.


### Restructure: the shared logic and a HAL per platform (2026-11-14, user: "split out the code into a HAL for C64 and apple, with
### separate Apple II vs GS graphics handling in the Apple code directory")

The layout is now `src/` (the logic, platform independent), `hal/c64/`, `hal/apple/gs/` (this document's IIgs work, moved from
`apple2gs/`), `hal/apple/ii/` (the HGR experiment, from `apple2/`), `hal/apple/keymap.inc`; `hal/README.md` is the contract. The
display layer `hal.s` is now `hal/apple/gs/shr.s` (`shr_init`, `shr_present`, ...), since "hal" is the whole directory.
- **The C64 build was split first** (game.s into `hal/c64/game.s` + `src/{constants,vars,frame,init}` + `src/memory.inc`; input.s into
  the shared pressing order and `hal/c64/keys.s`; level.s's character-set code into `hal/c64/charset.s`; the waits, `screen_off/on` into
  `timing.s`; macros `HAL_*` for the few C64 pokes in lift.s). The first move was byte-identical to the old `game.prg`; the later splits
  are tested (`make test`: enemy pool, lift ride, play against the BBC game's state).
- **The IIgs no longer patches the C64 binary.** `hal/apple/gs/logic.s` assembles `src/` with `logic_hal.s` (the HAL stubs and
  `logic_start`) into `build/apple2gs/logic.bin`, loaded at 02:0801; the old `patch_game_image`, `iigs_patch.py`, the zone camera and
  the spike coupling report are gone. The logic reaches the platform through reverse trampolines (`tramp.s`: `frame_wait`,
  `wait_frames`, `hal_store_char`, `hal_main`) and the platform's table of entry points at `$2000` (`platform.s`, segment ENTRY). The
  platform keeps the keys in `KEYBITS` for `hal_scan_keys`. The logic's own `restart_game` now runs the title screen and new game, so
  the platform's duplicate of that sequence is gone.
- **Tests:** `make test` (C64) and `make test-apple2gs` (includes `test_iigs_display.py`, which now builds its logic image from
  `logic.bin`) pass. The Apple II HGR experiment is untouched apart from its directory.
- **Not yet:** the IIgs sound (silent stubs), a real Apple II (6502) platform on `hal/apple/ii/`.
