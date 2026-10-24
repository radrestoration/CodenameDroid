#!/usr/bin/env python3
"""The player's fast sprite plots (fast_uplayer_body, fast_fplayer_body in platform.s) against the BBC's loops they
replace, on random sprites at random places in the ring (including across its end): the same bytes in the ring, the same
zero page, the same self-modified sprite address, the same X and Y.   test_fastplot.py [cases]"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64sim import C64, RING_W  # noqa: E402

RING_END = 0x8000
RING = RING_END - RING_W * 32 * 8
OPS = {"u": (0x394e, 0x394f), "f": (0x39c3, 0x39c4)}


def run(c, label, state, regs):
    m = c.m
    ring, zp, sprite = state
    m[RING:RING_END] = ring
    m[0:0x100] = zp
    m[0x0100:0x0200] = sprite
    m[0x394e:0x3950] = b"\x00\x30"
    m[0x39c3:0x39c5] = b"\x00\x30"
    cpu = c.cpu
    cpu.a, cpu.x, cpu.y = regs
    c.call(label, max_steps=200000)
    zpb = bytearray(m[0:0x100])
    for j in list(range(0xd0, 0xe0)) + list(range(0xee, 0xfe)):          # (the engine's own scratch: src/zp.inc)
        zpb[j] = 0
    return (bytes(m[RING:RING_END]), bytes(zpb), bytes(m[0x394e:0x3950]), bytes(m[0x39c3:0x39c5]), cpu.x, cpu.y)


def main(n=300):
    c = C64()
    rnd = random.Random(7)
    bad = 0
    for k in range(n):
        flipped = k & 1
        w = 3 if k % 10 else rnd.choice((1, 2, 4))
        h = rnd.randint(1, 40) if k % 7 else rnd.choice((1, 8, 9, 31, 32))
        if k % 3 == 0:
            sa = RING_END - rnd.randint(1, 40) * 8 - rnd.randint(0, 7)          # near the end: cells wrap
        else:
            sa = rnd.randint(RING, RING_END - 1)
        ring = bytes(rnd.randrange(256) for _ in range(RING_END - RING))
        zp = bytearray(rnd.randrange(256) for _ in range(256))
        zp[0x70], zp[0x71] = sa & 255, sa >> 8
        spr = rnd.randint(0, 0x40)                # (the game's sprite data is below the stack at $01c0)
        zp[0x72], zp[0x73] = spr, 1
        zp[0x76], zp[0x77] = w, h
        sprite = bytes(rnd.randrange(256) for _ in range(256))
        state = (ring, bytes(zp), sprite)
        regs = (rnd.randrange(256), w, h)
        a, b = ("f", "plot_flipped_player_body") if flipped else ("u", "plot_unflipped_player_body")
        want = run(c, b, state, regs)
        got = run(c, "fast_fplayer_body" if flipped else "fast_uplayer_body", state, regs)
        names = ("ring", "zero page", "unflipped sprite address", "flipped sprite address", "X", "Y")
        diff = [nm for nm, x, y in zip(names, want, got) if x != y]
        # (the BBC's sprite loops read the sprite address operands they patched, so only the one used must agree)
        diff = [d for d in diff if d != ("flipped sprite address" if not flipped else "unflipped sprite address")]
        if diff:
            bad += 1
            if bad <= 5:
                extra = ""
                if "zero page" in diff:
                    i = [j for j in range(256) if want[1][j] != got[1][j]]
                    extra = " zp %s" % [(hex(j), want[1][j], got[1][j]) for j in i[:6]]
                print("case %d %s w=%d h=%d at %04x: differs in %s%s" % (k, a, w, h, sa, diff, extra))
    print("%d cases, %d differ" % (n, bad))
    print("PASS" if not bad else "FAIL")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(int(sys.argv[1]) if len(sys.argv) > 1 else 300))
