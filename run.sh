#!/bin/bash
# Build and run the game in VICE.
#   ./run.sh           PAL
#   ./run.sh ntsc      NTSC machine
#   ./run.sh cheat     the test build: keys 1-9 0 Q W go to levels 1-12, E energy and cards, R microfilm/key/spanner, T jet pack
#   ./run.sh intro     from the disk image with the loading screens first (build/c64/droid.d64)
#   ./run.sh warp      no speed limit
# Extra arguments go to x64sc.
cd "$(dirname "$0")" || exit 1
model=pal; extra=(); cheat=""; dir=build/c64; file=game.prg
for a in "$@"; do
  case $a in
    ntsc) model=ntsc ;;
    pal)  model=pal ;;
    warp) extra+=(-warp) ;;
    cheat) cheat=1; dir=build/c64-cheat ;;
    intro) file=droid.d64 ;;
    *)    extra+=("$a") ;;
  esac
done
make -s ${cheat:+CHEAT=1} || exit 1
args=(-autostartprgmode 1)
[ $model = ntsc ] && args+=(-model ntsc) || args+=(-model c64c)
exec x64sc "${args[@]}" "${extra[@]}" "$dir/$file"
