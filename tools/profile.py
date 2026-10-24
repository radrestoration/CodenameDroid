"""Profile the C64 build by routine: cycles spent per label region (labels from build/c64.lbl),
over a range of frames.   profile.py FIRST_FRAME LAST_FRAME [keys...]"""
import bisect
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64sim import C64  # noqa: E402


def profile(c, frames, top=25, held=None):
    labs = sorted((a, n) for n, a in c.syms.items() if not n.startswith("__"))
    addrs = [a for a, _ in labs]
    prof = collections.Counter()
    cpu = c.cpu
    target = c.frames + frames
    if held is not None:
        c.held = held
    total = 0
    while c.frames < target:
        pc = cpu.pc
        c0 = cpu.cycles
        cpu.step()
        d = cpu.cycles - c0
        i = bisect.bisect_right(addrs, pc) - 1
        prof[labs[i][1]] += d
        total += d
    print("total %d cycles over %d frames = %d per frame" % (total, frames, total // frames))
    for n, v in prof.most_common(top):
        print("  %-44s %8d /frame  %4.1f%%" % (n, v // frames, 100.0 * v / total))


if __name__ == "__main__":
    a, b = int(sys.argv[1]), int(sys.argv[2])
    c = C64()
    c.run_frames(a)
    profile(c, b - a)
