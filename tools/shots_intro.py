#!/usr/bin/env python3
"""Render the loading screens as the VIC-II would show them, to PNGs in build/c64/shots (for looking at).  shots_intro.py"""
import os
import sys

os.environ["C64_INTRO"] = "1"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402
from c64raster import C64Raster  # noqa: E402
import test_intro as t  # noqa: E402

PAL = [(0, 0, 0), (255, 255, 255), (136, 57, 50), (103, 182, 189), (139, 63, 150), (85, 160, 73), (64, 49, 141),
       (191, 206, 114), (139, 84, 41), (87, 66, 0), (184, 105, 98), (80, 80, 80), (120, 120, 120), (148, 224, 137),
       (120, 105, 196), (159, 159, 159)]


def render(c, split=None):
    m = c.m
    img = np.zeros((200, 320, 3), np.uint8)
    d011 = m[0xd011]
    bg = PAL[m[0xd021] & 15]
    img[:] = bg
    bitmap, colour = 0xe000, 0xd800
    for cy in range(25):
        for cx in range(40):
            i = cy * 40 + cx
            sc, cr = c.ram_d[i], m[colour + i] & 15
            for ln in range(8):
                if d011 & 0x20 and split is not None and cy >= split:       # hires bitmap: the logo screen's lower part
                    b = m[bitmap + (cy * 40 + cx) * 8 + ln]
                    for p in range(8):
                        img[cy * 8 + ln, cx * 8 + p] = PAL[sc >> 4] if (b >> (7 - p)) & 1 else PAL[sc & 15]
                elif d011 & 0x20:                   # multicolour bitmap
                    b = m[bitmap + (cy * 40 + cx) * 8 + ln]
                    cols = [PAL[m[0xd021] & 15], PAL[sc >> 4], PAL[sc & 15], PAL[cr]]
                    for p in range(4):
                        img[cy * 8 + ln, cx * 8 + p * 2:cx * 8 + p * 2 + 2] = cols[(b >> (6 - 2 * p)) & 3]
                else:                               # characters, hires or multicolour (colour RAM bit 3)
                    b = m[0xe000 + sc * 8 + ln]
                    if cr & 8:
                        cols = [PAL[m[0xd021] & 15], PAL[m[0xd022] & 15], PAL[m[0xd023] & 15], PAL[cr & 7]]
                        for p in range(4):
                            img[cy * 8 + ln, cx * 8 + p * 2:cx * 8 + p * 2 + 2] = cols[(b >> (6 - 2 * p)) & 3]
                    else:
                        for p in range(8):
                            img[cy * 8 + ln, cx * 8 + p] = PAL[cr] if (b >> (7 - p)) & 1 else bg
    return Image.fromarray(img)


def main():
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "c64", "shots")
    os.makedirs(out, exist_ok=True)

    def save(c, name, split=None):
        render(c, split).resize((640, 400), Image.NEAREST).save(os.path.join(out, name))
    c = C64Raster(pal=True)
    t.run_until(c, lambda: t.mode(c) == "text")
    t.frames(c, 5)
    save(c, "intro_m7_1.png")
    for n in range(2, 5):
        t.tap(c, t.SPACE)
        t.frames(c, 8)
    save(c, "intro_m7_4.png")
    c = C64Raster(pal=True)
    t.run_until(c, lambda: t.mode(c) == "text")
    t.frames(c, 3)
    t.tap(c, t.RUNSTOP)
    t.run_until(c, lambda: t.mode(c) == "bitmap")
    t.frames(c, 5)
    save(c, "intro1.png", 13)
    t.tap(c, t.Z)
    t.frames(c, 10)
    save(c, "intro2.png")
    t.tap(c, t.Z)
    t.frames(c, 10)
    save(c, "intro3.png")
    t.tap(c, t.V)
    t.frames(c, 10)
    save(c, "intro4.png")
    t.tap(c, t.SPACE)
    t.frames(c, 10)
    save(c, "intro5.png")
    print("wrote", out)


if __name__ == "__main__":
    main()
