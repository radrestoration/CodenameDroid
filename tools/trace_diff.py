#!/usr/bin/env python3
"""Find where the BBC and C64 builds first execute differently: run both with the same key script,
record (pc, a, x, y) for every instruction executed in the game code ($1100-$57ff) between two
vsyncs, and print the first difference with labels.

    trace_diff.py FRAME SCRIPT        (FRAME = the vsync at which they diverge; traces FRAME-1 .. FRAME)
"""
import bisect
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bbcsim import BBC  # noqa: E402
from c64sim import C64  # noqa: E402
import make_tables  # noqa: E402
import test_diff  # noqa: E402


def main(frame, script_text):
    script = test_diff.random_script(int(script_text[7:]), 5000) if script_text.startswith("random:") \
        else test_diff.parse_script(script_text)
    bbc, c64 = BBC(), C64()
    bbc.m[0xe400:0xe500] = bytes(make_tables.star_table())
    bbc.m[bbc.syms["variable_delay"]] = 0x60       # the same RTS the C64 build patches in (a busy-wait: timing only)
    for f in range(frame - 1):
        held = test_diff.keys_at(script, f)
        bbc.set_keys(*held)
        c64.held = [__import__("bbcsim").KEYS[k] for k in held]
        c64.apply_keys()
        bbc.run_frames(1)
        c64.run_frames(1)
    held = test_diff.keys_at(script, frame - 1)
    bbc.set_keys(*held)
    c64.held = [__import__("bbcsim").KEYS[k] for k in held]
    c64.apply_keys()

    def trace(sim, n):
        out = []
        cpu = sim.cpu
        target = sim.frames + n
        while sim.frames < target:
            pc = cpu.pc
            if 0x1100 <= pc < 0x5800:
                out.append((pc, cpu.a, cpu.x, cpu.y))
            cpu.step()
        return out
    tb, tc = trace(bbc, 1), trace(c64, 1)
    labs_b = sorted((a, n) for n, a in bbc.syms.items() if 0x1100 <= a < 0x5800 and not n.startswith("__"))
    labs_c = sorted((a, n) for n, a in c64.syms.items() if 0x1100 <= a < 0x5800 and not n.startswith("__"))
    lab = lambda L, pc: "%s+%d" % (L[bisect.bisect_right([a for a, _ in L], pc) - 1][1], pc - L[bisect.bisect_right([a for a, _ in L], pc) - 1][0])
    print("instructions in game code: bbc %d c64 %d" % (len(tb), len(tc)))
    for i in range(min(len(tb), len(tc))):
        if tb[i] != tc[i]:
            print("first difference at instruction %d:" % i)
            for j in range(max(0, i - 6), min(i + 3, len(tb), len(tc))):
                print("   bbc %04x A=%02x X=%02x Y=%02x %-40s | c64 %04x A=%02x X=%02x Y=%02x %s"
                      % (*tb[j], lab(labs_b, tb[j][0]), *tc[j], lab(labs_c, tc[j][0])))
            return 1
    print("identical game-code traces for that frame")
    return 0


if __name__ == "__main__":
    sys.exit(main(int(sys.argv[1]), sys.argv[2]))
