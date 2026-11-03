#!/bin/bash
# The headless checks (no emulator, no display). Run from the top directory after building:  make test
set -eo pipefail
cd "$(dirname "$0")/.."
P="python3 -I"
echo "== the enemy pool"
$P tools/test_enemy_pool.py
echo "== the lift ride and the display handoff"
$P tools/test_lift.py
echo "== in play against the BBC game's state (random keys, levels)"
$P tools/test_vs_bbc.py 200 1 0
$P tools/test_vs_bbc.py 200 2 1
