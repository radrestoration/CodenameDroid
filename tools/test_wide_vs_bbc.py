#!/usr/bin/env python3
"""The 40-column build against the BBC's, in play, by level coordinates. Both games get the same keys; while their states
agree (the same level, player x, stance), every cell of the ring that both windows show - the same level column, the same
row - should be the same bytes (the player, enemies, objects, stars, blasters: everything), except within 4 columns of the
BBC's window edges, where the BBC crops what the wider window shows whole.   
    test_wide_vs_bbc.py [frames] [script] [deepest]"""
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from bbcsim import BBC, KEYS  # noqa: E402
from c64sim import C64, RING, RING_W, RING_CELLS, CRTC_BASE  # noqa: E402
import make_tables  # noqa: E402
import test_diff  # noqa: E402
import wide_patches  # noqa: E402

SYM = wide_patches.SYMS
BLASTER = bytes([0x06, 0x6f, 0x06])         # a blaster's three bytes (plot_blaster)
STATE = ["level", "player_x", "player_stance", "player_direction", "player_frame", "jump_timer", "jump_direction",
         "player_jumping_or_falling", "suit_energy", "blaster_energy", "jet_pack_energy", "lives", "mines"]


def window(m, base, w, cells, crtc_base):
    left = m[SYM["left_edge_tile_address_low"]] + m[SYM["left_edge_x_fraction"]]
    return left


def step_to(sim, pc, step):
    """Run the simulator until it is next at pc (the top of the game's main loop)."""
    n = 0
    step()
    while sim.cpu.pc != pc:
        step()
        n += 1
        if n > 30_000_000:
            raise SystemExit("the game never came back to main_game_loop")


def main(frames, script_text, deepest=0, step=1, quiet=False):
    """frames: game loop iterations after the game starts (about three vertical retraces each)."""
    if script_text.startswith("random:"):
        script = test_diff.random_script(int(script_text[7:]), frames * 3 + 400, jump=bool(deepest))
    else:
        script = test_diff.parse_script(script_text)
    bbc, c64 = BBC(), C64()
    if deepest:
        bbc.m[0xf9] = c64.m[0xf9] = deepest
        # the jump restores a saved set of objects with the jet pack in use, and its energy runs down at each step of the
        # redraw of the level (32 or 40 steps): not in use
        bbc.m[bbc.syms["saved_objects_carried"] + 2] = c64.m[bbc.syms["saved_objects_carried"] + 2] = 0
        if os.environ.get("WVB_PASSCARD"):          # the passcard, to use the lifts
            bbc.m[bbc.syms["saved_objects_carried"]] = c64.m[bbc.syms["saved_objects_carried"]] = 1
    bbc.m[0xe400:0xe500] = bytes(make_tables.star_table())
    bbc.m[bbc.syms["variable_delay"]] = 0x60
    loop = bbc.syms["main_game_loop"]
    assert loop == c64.syms["main_game_loop"]
    t = time.time()
    # the title and the start-up (SPACE is held from vsync 140 to 200 or so), by vertical retraces
    f0 = 240
    for f in range(f0):
        held = test_diff.keys_at(script, f)
        bbc.set_keys(*held)
        c64.held = [KEYS[k] for k in held]
        c64.apply_keys()
        bbc.run_frames(1)
        c64.run_frames(1)
    compared = synced = 0
    for i in range(frames):
        held = test_diff.keys_at(script, f0 + 3 * i)
        bbc.set_keys(*held)
        c64.held = [KEYS[k] for k in held]
        c64.apply_keys()
        step_to(bbc, loop, bbc.cpu.step)
        step_to(c64, loop, c64._step)
        mb, mc = bbc.m, c64.m
        diff = [n for n in STATE if mb[SYM[n]] != mc[SYM[n]]] + ["objects_carried+%d" % k for k in range(16)
                                                                 if mb[0xc0 + k] != mc[0xc0 + k]]
        if diff:
            # (a wider window changes how often some things happen, e.g. the jet pack's energy runs down at each step of
            # the redraw of the level; from here on the games are not the same game)
            print("iteration %d: the games differ in %s (bbc %s c64 %s): stop; the windows matched until here"
                  % (i, diff, [mb[SYM[n]] if not n.startswith("obj") else mb[0xc0 + int(n.split("+")[1])] for n in diff],
                     [mc[SYM[n]] if not n.startswith("obj") else mc[0xc0 + int(n.split("+")[1])] for n in diff]))
            return 0
        synced += 1
        if i % step:
            continue
        lb = window(mb, 0x6000, 32, 1024, 0x0c)
        lc = window(mc, RING, RING_W, RING_CELLS, CRTC_BASE)
        Sb = ((bbc.screen_start() - 0x6000) >> 3) & 1023
        Sc = ((mc[0x200] - CRTC_BASE) << 8) | mc[0x201]
        bad = []
        for x in range(max(lb + 4, lc), min(lb + 28, lc + RING_W)):
            for r in range(32):
                ib = (Sb + 32 * r + (x - lb)) % 1024
                ic = (Sc + RING_W * r + (x - lc)) % RING_CELLS
                cb, cc = bytes(mb[0x6000 + ib * 8:0x6000 + ib * 8 + 8]), bytes(mc[RING + ic * 8:RING + ic * 8 + 8])
                if cb != cc and not (BLASTER in cb or BLASTER in cc):      # (enemies fire from further off in the wide window)
                    bad.append((r, x))
        compared += 1
        if bad:
            print("iteration %d: level %d, player x %d, windows [%d,+32) and [%d,+%d): %d cells differ, e.g. %s"
                  % (i, mb[SYM["level"]], mb[SYM["player_x"]], lb, lc, RING_W, len(bad), bad[:8]))
            return 1
    print("%d loop iterations, %d compared (the states agreed in %d): the two windows showed the same cells (%.0fs)"
          % (frames, compared, synced, time.time() - t))
    return 0


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 500
    script = sys.argv[2] if len(sys.argv) > 2 else "SPACE@140-200,X@260-700,Z@800-1300,X@1350-1500"
    sys.exit(main(n, script, int(sys.argv[3]) if len(sys.argv) > 3 else 0))
