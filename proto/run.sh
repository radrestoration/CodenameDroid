#!/bin/bash
# Build and run the engine prototype in VICE.   proto/run.sh [ntsc] [extra x64sc arguments]
cd "$(dirname "$0")/.." || exit 1
model=c64c
[ "$1" = ntsc ] && { model=ntsc; shift; }
make -s proto || exit 1
exec x64sc -model $model -autostartprgmode 1 "$@" build/proto/proto.prg
