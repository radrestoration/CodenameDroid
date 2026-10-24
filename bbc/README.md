# Codename Droid (BBC Micro) - cc65 rebuild

Codename Droid is (c) Superior Software 1987, by Nicholas Chamberlain and
Martin Edmondson. `codename-droid-disassembly.txt` is a reverse-engineered
disassembly of it (see the preamble there, and its list of pokes). This
directory turns that listing into source that ca65/ld65 assemble back into
the game, byte for byte.

The listing is of the **tape** release (its loader selects the tape filing
system). The target here is the **disc** release, the one on
`Disc032-CodenameDroidStrykersRun2.ssd`: its game file `CDroid4` is the same
game plus a different startup, and is rebuilt bit-for-bit.

    make              ../build/bbc/CDroid4 (the disc release), droid.ssd, standalone.ssd; then `make check`
    make tape         the tape release as the listing has it: ../build/bbc/DROID, DROID2
    make check        compare with the listing's bytes, the label addresses and the disc
    make run          b-em on ../build/bbc/droid.ssd (see ../tools.cfg)

(Run from `bbc/`. The build goes to `build/bbc/` at the top of the repository, next to the C64 port's `build/c64/`.)

Tools: cc65 (`../tools.cfg`, copied from `../tools.cfg.tmpl`, points at it; with an
installed cc65 nothing is needed) and python3. No beebasm needed.

## Discs

- `build/bbc/droid.ssd` is the original disc with its `CDroid4` replaced by the
  rebuilt one. Everything else on it (`!BOOT`, the BASIC front end, `CDroid`,
  `CDroid1-3`: the loader chain and loading screens) is the original's, taken
  from `Disc032` at build time. Because the rebuilt file is identical, this
  image is byte-identical to the original (`make` reports it).
- `build/bbc/standalone.ssd` has only the rebuilt `CDroid4` and a `!BOOT` of mine
  (`boot/boot.txt`): `MODE 5`, hide the screen while loading, `*RUN CDroid4`. It
  skips the original loader chain, so it has no loading screen and anything
  those files set up beyond what `disc_entry.s` does is missing. Untested.

## C64 port

The C64 port, which runs this game's own code with a C64 display layer, is in the directory above (`../C64-README.md`). It has been checked
in a headless simulator only, not on a C64 or in VICE.

## Layout

| | |
|---|---|
| `src/droid.s` | the game code, `&1100-&57ff` |
| `src/data.s` | the data blocks (tiles, level data, tables) that the entry code moves into place |
| `src/disc_entry.s` | the disc release's startup (exec `&6e00`); not in the listing, written from the disc's bytes |
| `src/tape_loader.s`, `src/tape_entry.s` | the tape release's loader (`&5800`) and DROID2 entry code (`&7b00`), from the listing |
| `src/symbols.inc` | named zero-page/RAM/OS addresses, from the listing's operand annotations |
| `src/disc.s`, `src/tape.s` | one assembly unit per release |
| `disc.cfg`, `tape.cfg` | ld65 layouts (data blocks are stored in the file but "run" at their final addresses) |
| `tools/` | `check_build.py`, `make_ssd.py`, and `disasm_to_ca65.py` + `droidlist.py` (the one-off listing conversion) |

`src/` is the source from here on. `tools/disasm_to_ca65.py` made the first
version from the listing; it has since been split and edited by hand and the
converter is kept only as provenance (`python3 tools/disasm_to_ca65.py LISTING DIR`
writes to any directory you give it).

CDroid4 layout: the game `&1100-&57ff`; the tile block at `&5800-&5fff` (in
place); `&6000-&6cff` staged for `&0400-&10ff`; `&6d00-&6dff` staged for the
four small blocks at `&03a0`, `&0180`, `&0380`, `&0300`; startup at `&6e00`.

## What `make check` proves

- `CDroid4` equals the file on the disc: all 24,064 bytes, including the
  startup code and the padding after it.
- The game and data blocks equal the listing's hex bytes (23,808 bytes), and
  1,077 labels are at the addresses the listing gives (the tape-only ones
  excluded).
- The tape build (`make tape`) equals the listing's bytes in both files, with
  all 1,091 labels where the listing puts them.
- The listing is internally inconsistent in five address-column entries (two
  tables and a sprite: lines 6370, 7696, 8212, 8213, 8672 - `ADDRESS_FIXES` in
  `tools/droidlist.py`), and one label (`skeleton_sprite_three`) sits one byte
  before the line it precedes. Each was settled against the disc, which has the
  bytes at the corrected addresses.
- The listing and the disc differ in two bytes, `&1201` (listing `ee`, disc
  `e4`: the high byte of `LDA &e400,Y`) and `&51f8` (listing `aa`, disc `3a`: one
  byte of level data), probably a difference between the releases. The source
  has the disc's values (`KNOWN_DISC_DIFFS`), so the tape build is the listing
  with those two bytes taken from the disc.

## Not verified

- **Nothing has been run** here; the images are built and checked statically.
- `standalone.ssd`'s `!BOOT` is mine.
- `tape` build's `!BOOT`: there is none; it is two files only.

## Source conventions

Labels are the listing's. The ones the listing repeats (`leave`, `skip_wraparound`,
...) have their address appended (`leave_1219`). A few jump targets that had no
label got `L_xxxx` (`L2_xxxx` in the data blocks). Operands are named only where
the listing annotated them with a plain identifier that always meant one address;
the zero-page temporaries the listing names differently per routine
(`tile_address`, `sprite_address_low`, ...) stay numbers with the listing's
annotation as the comment. The listing's `#` comments are kept as `;` comments.
