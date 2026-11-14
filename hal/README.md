# Platforms: the hardware abstraction layer

The game is the BBC game's rules, ported routine by routine (`src/`), on top of a small contract with the machine it runs on. A
platform is a directory here that supplies the other side of the contract; `src/` knows nothing of any hardware.

```
src/                 the game logic, shared by every platform (6502 code, one assembly unit with the platform's root file)
hal/c64/             Commodore 64: VIC-II character display with hardware sprites, SID sound, CIA keyboard
hal/apple/           what the Apple machines share (the keyboard map)
hal/apple/gs/        Apple IIgs: Super Hi-Res (software sprites), platform + display layer in bank 0, the logic in bank 2
hal/apple/ii/        Apple II: HGR (the scrolling experiment; no game yet)
```

## What the logic keeps and stages

The logic runs in its own 64 KB laid out as on the C64 (`src/memory.inc`; the other platforms keep it so the logic and its data run
unchanged). Each frame (`compute_frame`, `src/frame.s`) it reads the keys, takes game steps at the BBC's rate, and *stages* the
picture; it never touches a display register:

* a **40 x 25 matrix** of character numbers (`MAT_A` / `MAT_B`, `cur_buf` says which is shown) onto a level 256 columns wide;
  `cur_w` / `cur_cam` are the window, `t_xs` the C64's fine scroll
* each character's **BBC bytes** in `BPAT` (line n of character c at `BPAT + n * 256 + c`); `intern` / `set_char` make them
* up to 8 **sprites** as C64 hardware sprite registers (`p_sx`, `p_sy`, `p_ptr`, `p_msb`, `p_en`; images at `SPRAREA`)
* `ready` = 1 when a picture is staged; the platform shows it and sets `ready` to 0

## What a platform provides

Code (called with `jsr` from the logic; a platform may make any of them a stub):

| routine | meaning |
|---|---|
| `hal_scan_keys` | call `set_key` (key number in A) for every key held; `read_keys` (src/input.s) does the pressing order |
| `frame_wait`, `wait_frames` | until the next frame / A frames (the platform counts `tick`) |
| `hal_store_char` | character Y has just had its BBC bytes stored in `BPAT` (and `cb`): make it displayable |
| `hal_charset_reset`, `hal_clear_charset` | the C64's character-set housekeeping |
| `screen_off`, `screen_on` | blank the display while it is rebuilt |
| `hal_main` | the main loop (the logic jumps to it after the title screen and a new game) |
| `snd_osword`, `snd_flushall`, `snd_init` and the queue counts `qcnt` | the BBC's SOUND calls (src/sfx.s); silent stubs will do |

Macros (`hal.inc` of the platform): `HAL_WAIT_SHOWN` (wait until the staged picture has been taken over), `HAL_RAM_UNDER_IO`,
`HAL_IO_VISIBLE`, `HAL_SPRITES_ENABLE` (the C64's memory and sprite-chip pokes; nothing elsewhere), `BORDER` (a timing aid).

And the start-up: whatever the machine needs, then `init_mirror_table`, `rows_page` / `add` / `c64_pal`, `clear_buffers`,
`copy_sprites` and `restart_game` (which runs the title screen and `new_game`, then `jmp hal_main`) - see `start` in
`hal/c64/game.s` and `logic_start` in `hal/apple/gs/logic_hal.s`.

## The platforms

* **C64** (`hal/c64/game.s` is the program's root file, it includes `src/`): the VIC-II shows the matrix and the sprites; the
  raster interrupt takes over `ready`; `charset.s` converts characters, `keys.s` scans the CIA, `sound.s` is the SID driver,
  `timing.s` the waits. `intro.s` (the loading screens, its own program in `hal/c64/intro/`) and `cheat.s` are C64 only.
* **Apple IIgs** (`hal/apple/gs/`): `logic.s` assembles `src/` with `logic_hal.s` into bank 2 (6502 emulation mode); the stubs
  call the platform (`platform.s`, bank 0) through `tramp.s`'s reverse trampolines; `shr.s` is the Super Hi-Res display layer
  (picture in bank 1 shadowed to `$E1`, stack-slam scrolling, software sprites). See APPLE-II-HANDOFF.md.
* **Apple II** (`hal/apple/ii/`): the HGR scrolling experiment, to grow into a platform like the IIgs's.
