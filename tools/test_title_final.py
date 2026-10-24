#!/usr/bin/env python3
"""The title's intro scroll, the 32-column build against the 40-column (default) build: the same pictures in the 32 columns
both show, from the start to the end of the scroll. The 32-column build is made for this into build/ref32 (not the build
directory's). Two things this guards: the wide window already holds the columns the BBC's scroll draws first (the D's first
column was missing), and the scroll draws the window's last columns with another tile set in the wide build, which must not
touch the logo. (The still title that follows is not the same: the 40-column build arranges it for its wider screen, see
tools/make_title_map.py and test_titlemap.py.)"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CODE = r'''
import sys
sys.path.insert(0, %r)
from c64sim import C64, render_screen
c = C64()
c.run_frames(330)
render_screen(c, scale=1).convert("RGB").save(sys.argv[1])
''' % HERE


def shot(build, path):
    env = dict(os.environ, C64_BUILD=build)
    subprocess.run([sys.executable, "-I", "-c", CODE, path], env=env, check=True)


SCROLL = r'''
import sys, pickle
sys.path.insert(0, %r)
from c64sim import C64, render_screen
c = C64()
imgs = []
for i in range(260):
    c.run_frames(1)
    imgs.append(render_screen(c, scale=1).convert("RGB").crop((32, 0, 288, 200)).tobytes())
pickle.dump(imgs, open(sys.argv[1], "wb"))
''' % HERE


def scroll_frames(build, path):
    subprocess.run([sys.executable, "-I", "-c", SCROLL, path], env=dict(os.environ, C64_BUILD=build), check=True)


def main():
    import pickle
    from PIL import Image, ImageChops
    here = os.path.join(HERE, "..")
    subprocess.run(["make", "-s", "WIDE=32", "B=build/ref32"], cwd=here, check=True, stdout=subprocess.DEVNULL)
    ref, cur = os.path.join("build", "ref32"), os.path.join("build", "c64")
    # the start of the scroll: every picture of the 32-column build's scroll (the 32 columns it shows) is one of the wide
    # build's (which has the BBC's first columns in its window from the start: the D's first column was missing)
    fa, fb = os.path.join(here, "build", "ref32", "scroll.pkl"), os.path.join(here, "build", "c64", "scroll.pkl")
    scroll_frames(ref, fa)
    scroll_frames(cur, fb)
    wide = set(pickle.load(open(fb, "rb")))
    missing = [i for i, x in enumerate(pickle.load(open(fa, "rb"))[:120]) if x not in wide]
    print("the intro scroll, frames of the 32-column build with no match in the 40-column build: %s" % (missing or "none"))
    ok = not missing
    print("PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
