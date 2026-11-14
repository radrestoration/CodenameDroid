#!/bin/bash
# Build an Apple IIgs disk image and run it in GSplus (ROM 01).
#   ./run-apple2gs.sh        the game (milestone 1): the C64 port's logic on the IIgs - walk around level 0, no sprites yet
#                            X/Z or right/left arrows walk, Open Apple (or RETURN) jumps, Closed Apple/Option (or =) fires,
#                            ; and / (or up/down arrows) climb; one ordinary key at a time plus the two Apple keys
#   ./run-apple2gs.sh demo   the level scroller: Z/X or arrows scroll sideways, K/M or up/down arrows vertically
#   ./run-apple2gs.sh bars   the first test: 16 grey bars from a single boot block
# Extra arguments go to GSplus, e.g. -fullscreen 1. A red border means the loader could not read the disk.
set -e
cd "$(dirname "$0")"
[ ! -f tools.cfg ] || . ./tools.cfg
GSPLUS=${GSPLUS:-$HOME/retro/emulators/gsplus/build/gsplus}
GSPLUS_ROM=${GSPLUS_ROM:-$HOME/retro/emulators/gsplus/ROM.01}
[ -x "$GSPLUS" ] || { echo "GSplus not found at $GSPLUS (set GSPLUS in tools.cfg)" >&2; exit 1; }
[ -f "$GSPLUS_ROM" ] || { echo "ROM not found at $GSPLUS_ROM (set GSPLUS_ROM in tools.cfg)" >&2; exit 1; }
case "$1" in
    bars) shift; make -s apple2gs-bars; IMAGE=bars.po ;;
    demo) shift; make -s apple2gs-demo; IMAGE=demo/demo.po ;;
    *)    make -s apple2gs-boot; IMAGE=game/droid-gs.po ;;
esac
exec "$GSPLUS" -cfg "$PWD/build/apple2gs/config.kegs" -rom "$GSPLUS_ROM" -s5d1 "$PWD/build/apple2gs/$IMAGE" "$@"
