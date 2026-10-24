"""Capture the BBC game's special screens (whole 32-row screen buffer) as PNGs in build/shots, and list the cell rows
whose interior (columns 4-27) is blank.   capture_screens.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bbcsim import BBC
from ringview import ring_image
import test_diff, make_tables
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "c64", "shots")
S = lambda b: ((b.m[0x81] << 8 | b.m[0x80]) - 0xc00) & 0x3ff


def blank_rows(b, c0=4, c1=28):
    s, out = S(b), []
    for r in range(32):
        if not any(any(b.m[0x6000 + ((s + 32 * r + c) & 1023) * 8:0x6000 + ((s + 32 * r + c) & 1023) * 8 + 8]) for c in range(c0, c1)):
            out.append(r)
    return out


def capture(name, script_text, stop_frame=None, at_rdch=False, deepest=0):
    b = BBC(); b.stop_at_rdch = at_rdch
    b.m[0xe400:0xe500] = bytes(make_tables.star_table())
    b.m[b.syms["variable_delay"]] = 0x60
    if deepest:
        b.m[0xf9] = deepest
    script = test_diff.parse_script(script_text)
    shot = {}
    try:
        for f in range(stop_frame or 900):
            b.set_keys(*test_diff.keys_at(script, f)); b.run_frames(1)
    except BBC.WaitingForKey:
        pass
    im, rows = ring_image(b.m, S(b), 1)
    im.save(os.path.join(OUT, "bbc_%s.png" % name))
    print("%-9s frame %d  blank interior rows: %s" % (name, f, blank_rows(b)), flush=True)


os.makedirs(OUT, exist_ok=True)
capture("title", "", 110)
capture("title2", "", 175)
capture("terminal", "SPACE@140-200,A@330-400", at_rdch=True)
capture("gameover", "SPACE@140-200,ESCAPE@330-334", 520)
capture("map", "J@140-146,A@300-304", 420, deepest=1)
