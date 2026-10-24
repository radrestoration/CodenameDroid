#!/usr/bin/env python3
"""Where do the BBC and C64 builds first write a different value to an address?  (A divergence found by test_diff.)

    trace_writes.py FRAME SCRIPT [DEEPEST] ADDR     ADDR in hex, e.g. 76; records the writes to it during the frame FRAME-1..FRAME
    (C64_BUILD selects the C64 build.)"""
import bisect
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bbcsim import BBC, KEYS  # noqa: E402
from c64sim import C64  # noqa: E402
import make_tables  # noqa: E402
import test_diff  # noqa: E402

ZP = test_diff.ZP_MAP
WINDOW = int(os.environ.get("WINDOW", "6"))      # frames before FRAME to record from


def main(frame, script_text, deepest, addr):
    script = test_diff.random_script(int(script_text[7:]), 5000, jump=bool(deepest)) if script_text.startswith("random:") \
        else test_diff.parse_script(script_text)
    bbc, c64 = BBC(), C64()
    if deepest:
        bbc.m[0xf9] = c64.m[0xf9] = deepest
    bbc.m[0xe400:0xe500] = bytes(make_tables.star_table())
    bbc.m[bbc.syms["variable_delay"]] = 0x60
    for f in range(frame - 1 - WINDOW):
        held = test_diff.keys_at(script, f)
        bbc.set_keys(*held)
        c64.held = [KEYS[k] for k in held]
        c64.apply_keys()
        bbc.run_frames(1)
        c64.run_frames(1)
    logs = {"bbc": [], "c64": []}
    ba, ca = addr, ZP.get(addr, addr)
    bbc.cpu.write_hooks.append(lambda a, v: logs["bbc"].append((v, bbc.cpu.pc)) if a == ba else None)
    c64.cpu.write_hooks.append(lambda a, v: logs["c64"].append((v, c64.cpu.pc)) if a == ca else None)
    for f in range(frame - 1 - WINDOW, frame + 1):
        held = test_diff.keys_at(script, f)
        bbc.set_keys(*held)
        c64.held = [KEYS[k] for k in held]
        c64.apply_keys()
        bbc.run_frames(1)
        c64.run_frames(1)

    def lab(syms, pc):
        items = sorted((a, n) for n, a in syms.items() if not n.startswith("__"))
        k = bisect.bisect_right([a for a, _ in items], pc) - 1
        return "%s+%d" % (items[k][1], pc - items[k][0])
    print("writes to %02x: bbc %d, c64 %d" % (addr, len(logs["bbc"]), len(logs["c64"])))
    for i in range(max(len(logs["bbc"]), len(logs["c64"]))):
        b = logs["bbc"][i] if i < len(logs["bbc"]) else None
        c = logs["c64"][i] if i < len(logs["c64"]) else None
        mark = "" if (b and c and b[0] == c[0]) else "   <== differs"
        print("%3d bbc %-14s %-40s | c64 %-14s %s%s" % (
            i, ("%02x" % b[0]) if b else "-", lab(bbc.syms, b[1]) if b else "", ("%02x" % c[0]) if c else "-",
            lab(c64.syms, c[1]) if c else "", mark))
        if mark and i > 3:
            break


if __name__ == "__main__":
    a = sys.argv[1:]
    main(int(a[0]), a[1], int(a[2]) if len(a) > 3 else 0, int(a[-1], 16))
