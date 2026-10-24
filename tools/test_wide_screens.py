#!/usr/bin/env python3
"""The special screens of the 40-column build against the BBC's: the wrist terminal, the map, the jet pack screen, game
over. They are drawn in the leftmost 32 columns of the wide window; each is compared with the BBC's, cell by cell in window
coordinates, at the same point of the game (waiting for a key).      test_wide_screens.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from bbcsim import BBC, KEYS  # noqa: E402
from c64sim import C64, RING, RING_W, RING_CELLS, CRTC_BASE  # noqa: E402
import make_tables  # noqa: E402
import test_diff  # noqa: E402
import wide_patches  # noqa: E402

SYM = wide_patches.SYMS


def run_to(sim, step, until_pc=None, limit=40_000_000):
    n = 0
    try:
        while n < limit:
            if until_pc is not None and sim.cpu.pc == until_pc:
                return True
            step()
            n += 1
    except (BBC.WaitingForKey, C64.WaitingForKey):
        return True
    return False


def cells(bbc_or_c64, which):
    m = bbc_or_c64.m
    if which == "bbc":
        S = ((bbc_or_c64.screen_start() - 0x6000) >> 3) & 1023
        return lambda r, c: bytes(m[0x6000 + ((S + 32 * r + c) % 1024) * 8:0x6000 + ((S + 32 * r + c) % 1024) * 8 + 8])
    S = ((m[0x200] - CRTC_BASE) << 8) | m[0x201]
    return lambda r, c: bytes(m[RING + ((S + RING_W * r + c) % RING_CELLS) * 8:RING + ((S + RING_W * r + c) % RING_CELLS) * 8 + 8])


def compare(name, bbc, c64, region=None):
    """region = (first row, last row, first column, last column): the game over box lies over the level's picture, which
    the two windows show shifted (the wide one starts further left)"""
    cb, cc = cells(bbc, "bbc"), cells(c64, "c64")
    r0, r1, c0, c1 = region or (0, 31, 0, 31)
    bad = [(r, c) for r in range(r0, r1 + 1) for c in range(c0, c1 + 1) if cb(r, c) != cc(r, c)]
    rows = {}
    for r, c in bad:
        rows.setdefault(r, []).append(c)
    print("%-9s %s" % (name, "identical in its 32 columns" if not bad else "%d cells differ, rows %s" % (len(bad), sorted(rows)[:12])))
    return len(bad)


def both(script_text, until=None, deepest=0, pokes=(), rdch=(), frames=2000):
    """Run both with the script until each stops (waiting for a key, or at the label until)."""
    bbc, c64 = BBC(), C64()
    for s in (bbc, c64):
        s.stop_at_rdch = until is None
        s.rdch_keys = list(rdch)
    bbc.m[0xe400:0xe500] = bytes(make_tables.star_table())
    bbc.m[bbc.syms["variable_delay"]] = 0x60
    if deepest:
        bbc.m[0xf9] = c64.m[0xf9] = deepest
    script = test_diff.parse_script(script_text)
    pc = bbc.syms[until] if until else None
    done = [False, False]
    for f in range(frames):
        for pf, a, v in pokes:
            if pf == f:
                bbc.m[a] = c64.m[a] = v
        held = test_diff.keys_at(script, f)
        bbc.set_keys(*held)
        c64.held = [KEYS[k] for k in held]
        c64.apply_keys()
        # one retrace each, unless it is at the end of what it does
        for k, (sim, step) in enumerate(((bbc, bbc.cpu.step), (c64, c64._step))):
            if done[k]:
                continue
            target = sim.frames + 1
            try:
                while sim.frames < target:
                    if pc is not None and f > 150 and sim.cpu.pc == pc:
                        done[k] = True
                        break
                    step()
            except (BBC.WaitingForKey, C64.WaitingForKey):
                done[k] = True
        if all(done):
            return bbc, c64
    raise SystemExit("the screen was never reached (%s)" % (done,))


def main():
    bad = 0
    # the wrist terminal: A in play
    bbc, c64 = both("SPACE@140-200,A@330-400")
    bad += compare("terminal", bbc, c64)
    # the map: the terminal, then M (with the microfilm)
    bbc, c64 = both("J@140-146,A@330-400", until="map_screen_loop", deepest=1, pokes=[(280, 0xcc, 1)], rdch=[0x4d])
    bad += compare("map", bbc, c64)
    # the jet pack screen: J in play, with the jet pack
    bbc, c64 = both("SPACE@140-200,J@330-340", until="jet_pack_screen_loop", pokes=[(250, 0xc2, 1)])
    bad += compare("jet pack", bbc, c64)
    # game over: give up (ESCAPE) after SPACE
    bbc, c64 = both("SPACE@140-200,ESCAPE@330-334", until="game_over_screen_loop", pokes=[(250, SYM["lives"], 1)])
    bad += compare("game over", bbc, c64, region=(8, 22, 8, 24))
    print("PASS" if bad == 0 else "FAIL")
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
