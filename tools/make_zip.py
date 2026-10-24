#!/usr/bin/env python3
"""The distribution zip: the PRG and the disk image, a VICE run script and the top level README.md.   make_zip.py BUILD_DIR OUT.zip"""
import os
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))


def main(build, out):
    top = os.path.splitext(os.path.basename(out))[0]
    files = [(os.path.join(build, "droid.prg"), "droid.prg", 0o644), (os.path.join(build, "droid.d64"), "droid.d64", 0o644),
             (os.path.join(HERE, "dist_run.sh"), "run.sh", 0o755), (os.path.join(HERE, "..", "README.md"), "README.md", 0o644)]
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for src, name, mode in files:
            info = zipfile.ZipInfo("%s/%s" % (top, name), date_time=(2026, 10, 23, 0, 0, 0))
            info.external_attr = (0o100000 | mode) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, open(src, "rb").read())
    print("wrote %s (%d bytes)" % (out, os.path.getsize(out)))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
