"""Render the C64 display (from the simulator's memory) at the title, in play, in the wrist terminal and at game over,
driving the real keyboard-scan code through a model of the keyboard matrix.   shots_c64.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64sim import C64, render_screen
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "c64", "shots")
KEY = {"SPACE": (7, 4), "A": (1, 2), "ESC": (7, 7), "X": (2, 7), "Z": (1, 4), "RETURN": (0, 1)}
c = C64(scan="real")
plan = {130: "title", 300: "play", 420: "terminal", 640: "play_after", 840: "gameover"}
hold = [("SPACE", 140, 200), ("A", 330, 336), ("SPACE", 440, 446), ("X", 560, 640), ("ESC", 700, 704)]
for f in range(900):
    c.pressed = {KEY[k] for k, a, b in hold if a <= f < b}
    if f >= 700:
        c.run_cycles(17095)                 # (the game-over screen never waits for the frame)
    else:
        c.run_frames(1)
    if f in plan:
        name = plan[f]
        render_screen(c, 2).save(os.path.join(OUT, "c64_%s.png" % name))
        print("frame %d %s: level %d gamemode %d cam %d" % (f, name, c.m[0x9f], c.m[0x207], c.m[0x203]), flush=True)
