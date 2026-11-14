#!/bin/bash
set -e
cd "$(dirname "$0")"
[ ! -f tools.cfg ] || . ./tools.cfg
LINAPPLE=${LINAPPLE:-linapple}
make -s apple2-experiment
cp hal/apple/ii/linapple.conf build/apple2/linapple.conf
exec "$LINAPPLE" -c "$PWD/build/apple2/linapple.conf" -P "$PWD/build/apple2/scroll.apl"
