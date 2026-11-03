#!/bin/bash
# Build and run the native game in VICE.
#   native/run.sh           PAL
#   native/run.sh ntsc      NTSC machine
#   native/run.sh cheat     the test build: keys 1-9 0 Q W go to levels 1-12, E energy and cards, R microfilm/key/spanner, T jet pack
#   native/run.sh intro     from the disk image with the loading screens first (build/native/droid.d64)
#   native/run.sh warp      no speed limit
# Extra arguments go to x64sc.
cd "$(dirname "$0")/.." || exit 1
model=pal; extra=(); cheat=""; dir=build/native; file=game.prg
for a in "$@"; do
  case $a in
    ntsc) model=ntsc ;;
    pal)  model=pal ;;
    warp) extra+=(-warp) ;;
    cheat) cheat=1; dir=build/native-cheat ;;
    intro) file=droid.d64 ;;
    *)    extra+=("$a") ;;
  esac
done
make -s native ${cheat:+CHEAT=1} || exit 1
args=(-autostartprgmode 1)
[ $model = ntsc ] && args+=(-model ntsc) || args+=(-model c64c)
exec x64sc "${args[@]}" "${extra[@]}" "$dir/$file"
