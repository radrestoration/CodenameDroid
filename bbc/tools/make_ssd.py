#!/usr/bin/env python3
"""Make a disc image of the rebuilt game.

    make_ssd.py disc    BUILD_DIR ORIGINAL.ssd OUT.ssd
        the original disc with its CDroid4 replaced by the rebuilt one (same
        length, so same sectors) - everything else on it (the loader chain,
        the loading screens) is the original's
    make_ssd.py standalone BUILD_DIR OUT.ssd
        a disc with only the rebuilt CDroid4 and a !BOOT (boot/boot.txt)
"""
import os
import sys

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
from check_build import dfs_file  # noqa: E402
from make_bbc_ssd import build_ssd  # noqa: E402


def main(argv):
    mode, build = argv[0], argv[1]
    mine = open(os.path.join(build, "CDroid4"), "rb").read()
    if mode == "disc":
        orig = bytearray(open(argv[2], "rb").read())
        cat1 = orig[256:512]
        for i in range(cat1[5] // 8):
            if orig[8 + 8 * i:15 + 8 * i].decode("latin1").rstrip() == "CDroid4":
                m = cat1[8 + 8 * i:16 + 8 * i]
                sector = m[7] | (m[6] & 3) << 8
                length = m[4] | m[5] << 8 | ((m[6] >> 4) & 3) << 16
                assert length == len(mine), (length, len(mine))
                orig[sector * 256:sector * 256 + length] = mine
                break
        else:
            raise SystemExit("no CDroid4 on %s" % argv[2])
        open(argv[3], "wb").write(orig)
        print("wrote %s" % argv[3])
    else:
        boot = open(os.path.join(here, "..", "boot", "boot.txt"), "rb").read()
        files = [("!BOOT", 0, 0, boot), ("CDroid4", 0x1100, 0x6e00, mine)]
        open(argv[2], "wb").write(build_ssd(files, title="CODENAME", boot_option=3))
        print("wrote %s" % argv[2])


if __name__ == "__main__":
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    main(sys.argv[1:])
