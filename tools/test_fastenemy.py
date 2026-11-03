#!/usr/bin/env python3
"""The enemies' fast sprite plots (c64_fenemy_go, c64_sprite_go in enemy.s) against the BBC's loops they shortcut, on random
sprites at random cells of the ring (including across its end): the same bytes in the ring and the same zero page.
test_fastenemy.py [cases]"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64sim import C64, RING_W  # noqa: E402

RING_END = 0x8000
RING = RING_END - RING_W * 32 * 8


def run(c, label, state, orig_at, orig_bytes, fast):
    m = c.m
    ring, zp, low = state
    m[RING:RING_END] = ring
    keep = {j: m[j] for j in list(range(0xd0, 0xe0)) + list(range(0xee, 0xfe))}      # (the cell store's own zero page stays)
    m[0:0x100] = zp
    for j, v in keep.items():
        m[j] = v
    m[0x0100:0x0200] = low
    m[orig_at:orig_at + 3] = orig_bytes if not fast else FAST[orig_at]
    cpu = c.cpu
    cpu.a, cpu.x, cpu.y = 0, 3, 0
    c.call(label, max_steps=4000000)
    zpb = bytearray(m[0:0x100])
    for j in list(range(0xd0, 0xe0)) + list(range(0xee, 0xfe)):          # (the engine's own scratch: src/zp.inc)
        zpb[j] = 0
    for j in (0x74, 0x75):                                               # (column_screen_address afterwards: not kept; the flipped
        zpb[j] = 0                                                      # plot's screen address too)
    if label == 'plot_flipped_enemy_body':
        zpb[0x70] = zpb[0x71] = 0
    return bytes(m[RING:RING_END]), bytes(zpb)


FAST = {}


def main(n=400):
    c = C64()
    c.run_frames(3)                                               # (start copies the high code to $f600)
    S = c.syms
    hooks = {"f": (S["c64_fenemy_hook"], bytes([0x8d, 0x79, 0x3a]), "plot_flipped_enemy_body"),
             "u": (S["c64_sprite_hook"], bytes([0x8d, 0x19, 0x1c]), "plot_sprite_body")}
    for k, (at, orig, _) in hooks.items():
        FAST[at] = bytes(c.m[at:at + 3])
        assert c.m[at] == 0x4c, "the hook is not a jump"
    rnd = random.Random(11)
    bad = 0
    fast_taken = 0
    for k in range(n):
        kind = "f" if k & 1 else "u"
        at, orig, body = hooks[kind]
        h = rnd.choice((8, 16, 24, 32, 32, 32, 40)) if k % 6 else rnd.choice((5, 12, 33))
        w = 3 if k % 3 else rnd.choice((1, 2, 3))
        if k % 3 == 0:
            sa = RING_END - rnd.randint(1, 60) * 8
        else:
            sa = RING + rnd.randrange(0, (RING_END - RING) // 8) * 8
        if k % 11 == 0:
            sa += rnd.randint(1, 7)                                   # (not on a cell: the loops do it)
        ring = bytes(rnd.randrange(256) for _ in range(RING_END - RING))
        zp = bytearray(rnd.randrange(256) for _ in range(256))
        zp[0x70], zp[0x71] = sa & 255, sa >> 8
        zp[0x74], zp[0x75] = sa & 255, sa >> 8                         # (column_screen_address: set by the plot's start)
        spr = rnd.randint(0x60, 0xa0)
        zp[0x72], zp[0x73] = spr, 0x44                                 # (sprite data in the game's graphics: $4400 on)
        zp[0x76], zp[0x77] = w, h
        zp[0x78] = 0                                                   # sprite_offset
        low = bytes(rnd.randrange(256) for _ in range(256))
        state = (ring, bytes(zp), low)
        if kind == "f":
            c.m[0x3a78:0x3a7a] = b"\x00\x30"
        want = run(c, body, state, at, orig, False)
        got = run(c, body, state, at, orig, True)
        if want != got:
            bad += 1
            if bad <= 5:
                d = [j for j in range(256) if want[1][j] != got[1][j]]
                r = [j for j in range(len(want[0])) if want[0][j] != got[0][j]]
                print("case %d %s w=%d h=%d at %04x: ring differs at %d bytes %s, zp %s"
                      % (k, kind, w, h, sa, len(r), [hex(RING + j) for j in r[:4]], [(hex(j), want[1][j], got[1][j]) for j in d[:6]]))
    print("%d cases, %d differ" % (n, bad))
    print("PASS" if not bad else "FAIL")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(int(sys.argv[1]) if len(sys.argv) > 1 else 400))
