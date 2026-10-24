"""Profile the C64 build walking left in the Ancient Shrine (the title's debug jump): cycles by routine
over a stretch of scrolling.   profile_scroll.py [first_frame last_frame]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64sim import C64
from bbcsim import KEYS
from profile import profile
a, b = (int(sys.argv[1]), int(sys.argv[2])) if len(sys.argv) > 2 else (460, 520)
c = C64()
c.m[0xf9] = 1
for f in range(a):
    c.held = [KEYS["J"]] if 140 <= f < 146 else ([KEYS["Z"]] if f >= 450 else [])
    c.apply_keys()
    c.run_frames(1)
c.held = [KEYS["Z"]]
c.apply_keys()
profile(c, b - a, top=22, held=[KEYS["Z"]])
