# Codename Droid: Stryker's Run Part 2

**Codename Droid** (Superior Software, 1987, by Martin Edmondson and Nick Chamberlain) for the BBC Micro, rebuilt from its
disassembly, and a **Commodore 64 port** that runs the game's own code with a C64 display layer.

This is an AI port using Claude by Rad Restoration - contact@radrestoration.com.

Game has been tested in VICE and real NTSC C64 hardware. 

## Copyright and Ownership

Like many BBC Micro games, this software is considered abandonware, and the copyright status is unclear. 

This work was based upon disassembly here:

https://level7.org.uk/miscellany/codename-droid-disassembly.txt

For more on the original, see here:

https://bbcmicro.co.uk/game.php?id=564

## Commodore 64 Port Notes

The game aims to be a faithful port of the original, but there are some consessions:

 - The original BBC Micro game ran in Mode 5, which is 256 pixels vertically with a reduced width of 256 (actually, 128, 
   because the pixels are rectangular). The Commodore 64 version instead uses a play area of 320 (160 pixels) x 200 to give 
   a rectangular play area of about the same area. The game play logic was redone to accomodate this. Also the game
   implements a "camera follow" to allow for the larger vertical play area. 
 - Joystick - the game is not playable with the joystick alone, it is really a keyboard driven game as most BBC Micro 
   games were. This would require some major thinking and work to accomodate a fully joystick driven game. 
 - Music and sound - the conversion is pretty good, but the BBC Micro's sound chip and the C64 SID are fundamentally different
   instruments. 
 - Loading screens - poorly done because of the attempt to squeeze in graphics from one set of hardware restrictions to another. 

Otherwise, the game play and game play graphics, allowing for differences in palette should be identical to the original. 
Bullets use C64 hardware sprites, but everything else is rendered in character mode. 


## Running the C64 version

With VICE (`x64sc`): `./run.sh` (PAL), `./run.sh ntsc`, `./run.sh d64` (from the disk image), `./run.sh warp`. In the
release zip that is the `run.sh` beside `droid.prg` and `droid.d64`; in the source tree `./run.sh` builds first. Or load
`droid.prg` or `droid.d64` yourself (`LOAD"DROID",8,1`, `RUN`). The program detects PAL and NTSC itself.

It starts as the BBC disc does:
1. the instruction pages from the tape inlay (SPACE for each; RUN/STOP skips them),
2. the logo, then the full screen artwork scrolling up (any key moves on),
3. the credits: SPACE (or fire) starts the game, V shows the controls.

### Controls

| | keyboard | joystick (port 2) |
|---|---|---|
| walk | Z / X | left / right |
| up (climb, lift, stand) / down (kneel, crawl, descend) | `;` / `/` | up / down |
| jump (hold Z or X for a sideways jump) | RETURN | fire |
| fire the blaster | `=` | |
| wrist terminal / jet pack screen | A / J | |
| drop a mine / leave the jet pack | D / O | |
| pause / resume | P / DEL | |
| lose a life / give up | CTRL / RUN/STOP | |
| sound off / on | F1 / F3 | |

On the wrist terminal: S and B charge the suit and the blaster, M shows the map, SPACE leaves. The joystick controls are
provisional.

## Running the BBC version

The BBC game is rebuilt bit for bit from the disassembly (`bbc/`). From `bbc/`: `make run` starts b-em on the rebuilt disc
(see `tools.cfg`). Details in `bbc/README.md`.

## Building

You need cc65 (`ca65`, `ld65`), Python 3 with numpy and Pillow, and `c1541` (part of VICE). Copy `tools.cfg.tmpl` to
`tools.cfg` if cc65 is not on your path. The loading screens are made from the original disc image
(`Disc032-CodenameDroidStrykersRun2.ssd`, set `DISC` if it is not in `~/retro/games`); without it the build has no loading
screens. The build itself needs nothing from a BBC ROM.

    make            the C64 version: build/c64/droid.prg and droid.d64 (builds the BBC game into build/bbc first)
    make WIDE=32    the same with the BBC's 32-cell window instead of the default 40 (same directory)
    make zip        build/c64/codename-droid-c64.zip: the PRG, the disk image, run.sh and this file
    make test       the headless checks in the 6502 simulator (minutes)
    make help

## Notes

- `C64-README.md`: how the C64 port works (the display layer, the 40-column window, sound, the loading screens), what has
  been verified and what has not, the memory map and the tools.
- `bbc/README.md`: the BBC rebuild.
