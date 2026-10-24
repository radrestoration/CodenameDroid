"""Profile the heaviest vsync interval (the enemy update) in the Ancient Shrine, idle.
Runs to frame 300, then profiles frames until it has seen N intervals > 25,000 cycles."""
import bisect, collections, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64sim import C64
from bbcsim import KEYS
c = C64(); c.m[0xf9] = 1
for f in range(300):
    c.held = [KEYS["J"]] if 140 <= f < 146 else []
    c.apply_keys(); c.run_frames(1)
labs = sorted((a, n) for n, a in c.syms.items() if not n.startswith("__"))
addrs = [a for a, _ in labs]
cpu = c.cpu
prof = collections.Counter(); heavy = 0; total = 0
while heavy < 6 and c.frames < 900:
    start = cpu.cycles; local = collections.Counter(); target = c.frames + 1
    while c.frames < target:
        pc = cpu.pc; c0 = cpu.cycles; cpu.step()
        local[labs[bisect.bisect_right(addrs, pc) - 1][1]] += cpu.cycles - c0
    spent = cpu.cycles - start
    if spent > 17000:
        heavy += 1; total += spent
        for k, v in local.items(): prof[k] += v
print("%d heavy intervals, %d cycles each on average" % (heavy, total // heavy))
for k, v in prof.most_common(30): print("  %-46s %6d  %4.1f%%" % (k, v // heavy, 100.0 * v / total))
