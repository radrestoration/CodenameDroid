#!/bin/bash
# Build and run the game in VICE.
#   ./run.sh           PAL
#   ./run.sh ntsc      NTSC machine
#   ./run.sh cheat     the test build: keys 1-9 0 Q W go to levels 1-12, E energy and cards, R microfilm/key/spanner, T jet pack
#   ./run.sh intro     loading screens first, with build/c64/droid.d64 attached
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
    intro) file=intro.prg ;;
    *)    extra+=("$a") ;;
  esac
done
if [ "$file" = intro.prg ]; then
  make -s ${cheat:+CHEAT=1} "$dir/droid.d64" || exit 1
else
  make -s ${cheat:+CHEAT=1} || exit 1
fi
args=(-autostartprgmode 1)
[ $model = ntsc ] && args+=(-model ntsc) || args+=(-model c64c)
if [ "$file" = intro.prg ]; then
  args+=(-virtualdev8 +drive8truedrive +autostart-handle-tde -8 "$dir/droid.d64")
fi
exec x64sc "${args[@]}" "${extra[@]}" "$dir/$file"
