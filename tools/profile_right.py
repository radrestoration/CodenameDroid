"""Profile the C64 build walking right (as tools/measure_speed.py does): cycles by routine.  profile_right.py [first last]"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64sim import C64  # noqa: E402
from bbcsim import KEYS  # noqa: E402
from profile import profile  # noqa: E402

a, b = (int(sys.argv[1]), int(sys.argv[2])) if len(sys.argv) > 2 else (560, 700)
c = C64()
for f in range(a):
    k = ["SPACE"] if 140 <= f < 200 else (["Z"] if 450 <= f < 520 else [])
    c.held = [KEYS[x] for x in k]
    c.apply_keys()
    c.run_frames(1)
c.held = [KEYS["X"]]
c.apply_keys()
profile(c, b - a, top=24, held=[KEYS["X"]])
