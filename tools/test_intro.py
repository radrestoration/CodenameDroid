#!/usr/bin/env python3
"""The loading screens (src/intro.s) in the raster simulator (which models $d012, so the waits work):
  - the instruction pages (SPACE for each; RUN/STOP skips them) are what tools/mode7.py makes of the disc's MODE 7 program
  - the 6502 unpacker gives the pictures make_intro.py made (screen RAM and colour RAM set up for them)
  - the flow: picture 1, picture 2 (a key moves on), the credits, V for the controls pages and back, SPACE starts the game
  - the pictures time out after 8 seconds
  - afterwards the game runs as usual (the game's own display set-up, the sound driver in place)
It needs the disc the loading screens are made from (the Makefile finds it); without it it says so."""
import os
import sys

os.environ["C64_INTRO"] = "1"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_intro  # noqa: E402
import mode7  # noqa: E402
from c64raster import C64Raster  # noqa: E402

fails = []


def check(ok, what):
    print("%s %s" % ("ok " if ok else "BAD", what))
    if not ok:
        fails.append(what)


def key(col, mask):
    return (col, mask.bit_length() - 1)


Z, SPACE, V, RUNSTOP = key(1, 0x10), key(7, 0x10), key(3, 0x80), key(7, 0x80)


def run_until(c, cond, limit=3000):
    n = 0
    while not cond():
        c._step()
        n += 1
        assert n < limit * 20000 or c.frames < limit, "gave up"
        if c.frames > limit:
            raise AssertionError("gave up after %d frames" % limit)


def frames(c, n):
    t = c.cpu.cycles + n * c.frame_len
    while c.cpu.cycles < t:
        c._step()


def mode(c):
    d011, d016 = c.m[0xd011], c.m[0xd016]
    return "bitmap" if d011 & 0x20 and d011 & 0x10 else "text" if d011 & 0x10 else "off"


def tap(c, k, n=3):
    c.pressed.add(k)
    frames(c, n)
    c.pressed.discard(k)
    frames(c, n)


def scroll_test(c, disc):
    """Picture 2 scrolls: at every frame the shown buffer (bank, fine scroll) is the picture's lines pos to pos + 191, the
    top moves a line every 3 frames, and it is over after 130 steps."""
    from check_build import dfs_file
    top, extra = make_intro.scroll_picture(dfs_file(open(disc, "rb").read(), "CDroid2"), (0, 1, 6, 7))
    full = top + extra                                     # (32 cell rows and a blank one: 33 * 320 bytes)
    run_until(c, lambda: c.m[0xd011] == 0x37)              # (unpacked and set up)
    check(c.m[0xd011] == 0x37 and c.m[0xd018] == 0x48 and c.m[0xdd00] & 3 == 0, "the scroll starts at the top, bank 3")
    check(all(b == 0x23 for b in c.ram_d[:1000]) and all(b == 0x23 for b in c.m[0x5c00:0x5c00 + 1000]), "both buffers' screen RAM: red and cyan")
    bad, flips, seen, last, times = 0, 0, set(), None, {}
    start = c.cpu.cycles
    n = 0
    while c.m[0x27d] < 130 and mode(c) == "bitmap":
        # to raster line 200 of a frame
        t = c.cpu.cycles
        phase = (t % c.frame_len) // c.cyc_line
        target = t + ((200 - phase) % c.lines) * c.cyc_line
        while c.cpu.cycles < target:
            c._step()
        n += 1
        pos = c.m[0x27f]
        bank = c.m[0xdd00] & 3
        base = 0xe000 if bank == 0 else 0x6000
        c0, y = pos // 8, c.m[0xd011] & 7
        want = full[c0 * 320:c0 * 320 + 8000]
        if y != 7 - pos % 8 or bytes(c.m[base:base + 8000]) != want or (bank == 0) != (c0 % 2 == 0):
            bad += 1
        if pos not in times:
            times[pos] = n
        seen.add(pos)
        end = c.cpu.cycles + c.frame_len - 100             # (to just before the same line of the next frame)
        while c.cpu.cycles < end:
            c._step()
    check(bad == 0, "every frame shows the right lines of the picture (%d wrong)" % bad)
    check(seen == set(range(65)), "the top goes through every line from 0 to 64")
    gaps = {times[p + 1] - times[p] for p in range(1, 64)}
    check(gaps == {3}, "a line every 3 frames (gaps %s)" % sorted(gaps))
    secs = (c.cpu.cycles - start) / (c.frame_len * 50.0)
    check(7.4 < secs < 8.2, "130 steps take %.2f seconds" % secs)


def expected_page(n, pages):
    """(screen codes, colours) of instruction page n as intro.s should show them."""
    screen, colour = [32] * 1000, [1] * 1000
    for y, x, col, text in mode7.c64_page(pages[n]):
        for k, ch in enumerate(text):
            screen[y * 40 + x + k] = ch
            colour[y * 40 + x + k] = col
    return screen, colour


def main():
    disc = make_intro.find_inputs()
    if not os.path.exists(disc):
        print("no disc: the loading screens are not built; nothing to test")
        return 0
    c = C64Raster(pal=True)
    syms = c.syms
    from check_build import dfs_file
    d = open(disc, "rb").read()
    want1, want1s = make_intro.logo_picture(dfs_file(d, "CDroid1"), (0, 1, 4, 7))
    want2 = make_intro.picture(dfs_file(d, "CDroid2"), (0, 1, 6, 7))
    scroll = "INTRO_SCROLL = 1" in open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "c64", "gen", "intro_data.s")).read()
    front = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "c64", "gen", "DROID.bas")
    pages = mode7.run(front) if open(os.path.join(os.path.dirname(front), "intro_data.s")).read().count("INTRO_M7_PAGES = 0") == 0 else []
    # the instruction pages: each as the teletext interpreter has it, in the C64's lower case character set
    if pages:
        run_until(c, lambda: mode(c) == "text")
        frames(c, 3)
    bad = []
    for n in range(len(pages)):
        screen, colour = expected_page(n, pages)
        got = list(c.ram_d[:1000])
        gotc = [c.m[0xd800 + i] & 15 for i in range(1000)]
        if got != screen or any(gotc[i] != colour[i] for i in range(1000) if screen[i] != 32):
            bad.append(n + 1)
        if n + 1 < len(pages):
            tap(c, SPACE)
            frames(c, 30)                                  # (a page is Huffman decoded: about 15 frames)
    check(not bad, "the %d instruction pages show as expected (pages that differ: %s)" % (len(pages), bad or "none"))
    if pages:
        check(c.m[0xd018] == 0x48 and c.m[0xdd00] & 3 == 0, "text mode, screen RAM at $d000, VIC-II bank 3")
        tap(c, SPACE)
    run_until(c, lambda: mode(c) == "bitmap")
    check(mode(c) == "bitmap" and c.m[0xdd00] & 3 == 0, "picture 1 is up, in VIC-II bank 3")
    frames(c, 2)
    check(bytes(c.m[0xe000:0xe000 + 8000]) == want1, "picture 1's bitmap is what make_intro.py made")
    check(bytes(c.ram_d[:1000]) == want1s, "screen RAM: red and blue above the split, a pair of colours a cell below it")
    check(c.m[0xd800] & 15 == 1 and c.m[0xdbe7] & 15 == 1 and c.m[0xd016] in (0x08, 0x18), "colour RAM: white")
    frames(c, 100)
    check(mode(c) == "bitmap" and bytes(c.m[0xe000:0xe000 + 8000]) == want1, "still picture 1 after 2 seconds")
    tap(c, Z)
    if scroll:
        scroll_test(c, disc)
        run_until(c, lambda: mode(c) == "text")
        frames(c, 4)
    else:
        frames(c, 10)
        check(bytes(c.m[0xe000:0xe000 + 8000]) == want2 and all(b == 0x23 for b in c.ram_d[:1000]), "a key shows picture 2 (red and cyan)")
        # 8 seconds, PAL: no key
        t0 = c.cpu.cycles
        run_until(c, lambda: mode(c) == "text")
        secs = (c.cpu.cycles - t0) / (c.frame_len * 50.0)
        check(7.7 < secs < 8.3, "picture 2 goes on its own after %.2f seconds" % secs)
    frames(c, 2)
    scr = lambda r, col, n: bytes(c.ram_d[r * 40 + col:r * 40 + col + n]).decode("latin1")
    check(scr(0, 15, 10) == "PRESENTING", "credits: PRESENTING")
    check(scr(11, 12, 16) == "NICK CHAMBERLAIN" and scr(24, 10, 19) == "PRESS SPACE TO LOAD", "credits: names and the prompt")
    check(c.m[0xd800 + 80] == 9 and c.m[0xd800 + 11 * 40 + 12] == 1, "colour RAM: the strip multicolour, the text hires white")
    check(c.m[0xd022] == 2 and c.m[0xd023] == 5, "colours: red and green")
    # the digits and punctuation are the C64's (the character ROM over codes 32-63); the capitals are the front end's
    check(bytes(c.m[0xe000 + 0x30 * 8:0xe000 + 0x30 * 8 + 8]) == bytes(c.chargen[0x30 * 8:0x30 * 8 + 8]), "the digit 0 is the C64 ROM's")
    tap(c, V)
    frames(c, 40)
    check(scr(0, 5, 27) == "THE CONTROLS ARE AS FOLLOWS", "V shows the controls")
    tap(c, SPACE)
    frames(c, 40)
    check(scr(6, 7, 24) == "STRYKER'S WRIST TERMINAL", "SPACE shows the wrist terminal's")
    tap(c, SPACE)
    frames(c, 40)
    check(scr(0, 15, 10) == "PRESENTING", "SPACE goes back to the credits")
    tap(c, SPACE)
    run_until(c, lambda: c.m[0xdd00] & 3 == 1)                 # the game's own bank 2
    check(True, "SPACE starts the game (VIC-II bank 2)")
    frames(c, 30)
    check(c.m[0xd011] & 0x10 and c.m[0xd018] in (0xa8, 0xb8), "the game's display ($d018 %02x)" % c.m[0xd018])
    run, load = syms["__SOUNDC_RUN__"], syms["__SOUNDC_LOAD__"]
    prg = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "c64", "droid.prg"), "rb").read()
    check(bytes(c.m[run:run + 64]) == prg[2 + load - 0x801:2 + load - 0x801 + 64], "the sound driver was moved into place after them")
    # RUN/STOP skips the instruction pages
    if pages:
        c = C64Raster(pal=True)
        run_until(c, lambda: mode(c) == "text")
        frames(c, 3)
        tap(c, RUNSTOP)
        run_until(c, lambda: mode(c) == "bitmap")
        check(True, "RUN/STOP skips the instruction pages (picture 1 next)")
    print("PASS" if not fails else "FAIL: %d" % len(fails))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
