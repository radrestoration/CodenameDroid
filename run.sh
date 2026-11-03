#!/bin/bash
# Build (if needed) and run the C64 port in VICE.
#   ./run.sh           PRG autostart, PAL
#   ./run.sh ntsc      NTSC machine
#   ./run.sh d64       autostart from the .d64 instead
#   ./run.sh warp      no speed limit (to see how fast it can go)
#   ./run.sh cheat     the test build in which the player cannot die (build/cheat)
#   ./run.sh narrow    the BBC's 32-cell window instead of the default 40 (same build directory)
# Extra arguments go to x64sc.
cd "$(dirname "$0")" || exit 1
model=pal; ext=prg; wide=40; extra=(); cheat=""; dir=build/c64
for a in "$@"; do
  case $a in
    ntsc) model=ntsc ;;
    pal)  model=pal ;;
    d64)  ext=d64 ;;
    warp) extra+=(-warp) ;;
    narrow) wide=32 ;;
    cheat) cheat=1; dir=build/cheat ;;
    *)    extra+=("$a") ;;
  esac
done
make -s WIDE=$wide ${cheat:+CHEAT=1} || exit 1
args=(-autostartprgmode 1)
[ $model = ntsc ] && args+=(-model ntsc) || args+=(-model c64c)
exec x64sc "${args[@]}" "${extra[@]}" "$dir/droid.$ext"
