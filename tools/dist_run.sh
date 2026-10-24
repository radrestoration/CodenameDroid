#!/bin/bash
# Run Codename Droid (C64) in VICE.
#   ./run.sh           PRG autostart, PAL machine
#   ./run.sh ntsc      NTSC machine
#   ./run.sh d64       autostart from the disk image instead
#   ./run.sh warp      no speed limit
# Extra arguments go to VICE. Set VICE to use another emulator binary (default x64sc).
cd "$(dirname "$0")" || exit 1
vice=${VICE:-x64sc}
model=pal; ext=prg; extra=()
for a in "$@"; do
  case $a in
    ntsc) model=ntsc ;;
    pal)  model=pal ;;
    d64)  ext=d64 ;;
    warp) extra+=(-warp) ;;
    *)    extra+=("$a") ;;
  esac
done
args=(-autostartprgmode 1)
[ $model = ntsc ] && args+=(-model ntsc) || args+=(-model c64c)
exec "$vice" "${args[@]}" "${extra[@]}" "droid.$ext"
