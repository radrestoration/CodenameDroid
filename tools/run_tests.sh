#!/bin/bash
# All the headless checks of the C64 build (no emulator, no display). Run from the top directory:  make test
# WIDE=40 (the default): the 40-cell window, against the BBC's in the 32 columns they share; WIDE=32: the BBC's own
# window, identical to the BBC game's screen buffer and state at every vertical retrace.
set -eo pipefail
cd "$(dirname "$0")/.."
P="python3 -I"
WIDE=${WIDE:-40}
if [ "$WIDE" = 32 ]; then
echo "== static: the game's bytes differ from the BBC's only at the patch sites"
$P tools/check_game_diff.py | head -1
fi
echo "== keyboard and joystick scan"
$P tools/test_keys.py | tail -1
echo "== NTSC/PAL pacing (the real wait routine against a model of the raster)"
$P tools/test_pacing.py | tail -1
echo "== the sound driver: frequencies, queue, envelopes, voices"
$P tools/test_sound.py | tail -1
if [ "$WIDE" = 32 ]; then
echo "== camera"
$P tools/test_camera.py | tail -1
echo "== cell store invariants (title screen)"
$P tools/test_c64.py | head -1
echo "== same as the original: BBC build vs C64 build, screen buffer + game state at every vsync"
$P tools/test_diff.py 1200 "SPACE@140-200,X@300-420,Z@440-520,RETURN@540-550,X@560-640" 2>/dev/null | head -3
for seed in 1 2; do $P tools/test_diff.py 1500 random:$seed 2>/dev/null | head -1; done
$P tools/test_diff.py 1500 random:3 1 2>/dev/null | head -1
$P tools/test_diff.py 1500 random:4 2 2>/dev/null | head -1
else
echo "== the geometry helpers against a model of the ring's arithmetic"
$P tools/test_helpers.py
echo "== the special screens (32 columns of each) against the BBC's"
$P tools/test_wide_screens.py | tail -5
echo "== the title and its intro scroll against the 32-column build's"
$P tools/test_title_final.py
echo "== in play against the BBC's, by level coordinates (title, walking, levels, lifts)"
$P tools/test_wide_vs_bbc.py 600
$P tools/test_wide_vs_bbc.py 700 random:1
$P tools/test_wide_vs_bbc.py 700 random:5
WVB_PASSCARD=1 $P tools/test_wide_vs_bbc.py 450 "J@140-146,/@270-275,:@340-345,Z@420-560,X@600-700" 1
WVB_PASSCARD=1 $P tools/test_wide_vs_bbc.py 450 "J@140-146,Z@260-600,:@640-645,X@700-900" 2
$P tools/test_wide_vs_bbc.py 700 random:4 2
echo "== the engine: cell store, camera"
$P tools/test_c64.py | head -1
$P tools/test_camera.py | tail -1
fi
echo "== scrolling right shows the picture and its display start together (no stray column)"
$P tools/test_scroll.py | tail -1
echo "== the lookup tables made at start-up"
$P tools/test_tables.py | tail -1
echo "== the fast sprite plots against the BBC loops they replace"
$P tools/test_fastplot.py | tail -1
echo "== the loading screens: unpacker, flow, timing"
$P tools/test_intro.py | tail -1
echo "== real raster wait + asynchronous raster interrupt, PAL and NTSC (title scroll, start, walking)"
$P tools/test_raster.py | tail -3
echo "== display: matrix matches the buffer and the camera keeps the player on screen"
$P tools/test_view.py 5 1500 1
