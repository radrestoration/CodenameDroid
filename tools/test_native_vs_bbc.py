#!/usr/bin/env python3
"""The native engine (native/, build/native) against the BBC game, by game state: both get the same keys at each pass of the
game's main loop, and the player's state, the energies, the objects carried and the enemies' variables must agree after each.
(Enemies do not fire in this test, as the two games' random numbers differ, and the terminal and jet pack screens are not used.)

    test_native_vs_bbc.py [iterations] [seed] [deepest]      deepest: 1 shrine, 2 quarters (the BBC's debug jump)
"""
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "native"))
from bbcsim import BBC  # noqa: E402
import make_tables  # noqa: E402
import sim_check as sc  # noqa: E402

NATIVE_KEY = {"X": 1, "Z": 2, ":": 3, "/": 4, "RETURN": 7, "]": 8, "D": 13, "O": 15}
POOL = ["X", "X", "X", "Z", "Z", "Z", ":", "/", "RETURN", "RETURN", "]", "O"]

# BBC zero page
ZP = dict(player_x=0x93, player_direction=0x94, player_frame=0x92, jump_direction=0x95, jump_timer=0x96,
          player_jumping_or_falling=0x8f, player_stance=0x6d, suit_energy=0x6f, blaster_energy=0x5b, lives=0x5a, mines=0x60,
          level=0x9f)
NAT = dict(player_x="px", player_direction="pdir", player_frame="pframe", jump_direction="jump_direction",
           jump_timer="jump_timer", player_jumping_or_falling="pjf", player_stance="pstance", suit_energy="suit_energy",
           blaster_energy="blaster_energy", lives="lives", mines="nmines", level="level")


def bbc_place(b):
    m = b.m
    start = b.screen_start()
    addr = m[0x90] | m[0x91] << 8
    d = ((addr - 0x6000) - (start - 0x6000)) & 0x1fff
    left = m[0x86] + m[0x84]
    return left + ((d & 255) >> 3), (d >> 8) * 8 + (d & 7)


def main(iterations=300, seed=1, deepest=0):
    rnd = random.Random(seed)
    bbc = BBC()
    if deepest:
        bbc.m[0xf9] = deepest
        bbc.m[bbc.syms["saved_objects_carried"] + 2] = 0
    bbc.m[0xe400:0xe500] = bytes(make_tables.star_table())
    bbc.m[bbc.syms["variable_delay"]] = 0x60
    bbc.m[bbc.syms["consider_enemy_firing"]] = 0x60          # RTS: no firing
    loop = bbc.syms["main_game_loop"]
    # to the start of the game
    for f in range(260):
        bbc.set_keys(*(["J"] if deepest and 140 <= f < 146 else ["SPACE"] if not deepest and 140 <= f < 200 else []))
        bbc.run_frames(1)
    n = 0
    bbc.cpu.step()
    while bbc.cpu.pc != loop:
        bbc.cpu.step()
    # the native engine in the same place
    mc = sc.Machine(True)
    lb = sc.labels(os.path.join(HERE, "..", "build", "native", "game.lbl"))
    c = mc.cpu
    m = c.m
    for f in range(120):
        mc.pressed = {"SPACE"} if 30 < f < 45 else set()
        mc.run_frame()
    mc.pressed = set()

    def call(name):
        sav = (c.pc, c.a, c.x, c.y, c.sp)
        sentinel = 0x0200
        c.push((sentinel - 1) >> 8)
        c.push((sentinel - 1) & 255)
        c.pc = lb[name]
        k = 0
        while c.pc != sentinel and k < 5_000_000:
            c.step()
            k += 1
        c.pc, c.a, c.x, c.y, c.sp = sav
        return k

    def setn(name, v, i=0):
        m[lb[name] + i] = v

    def getn(name, i=0):
        return m[lb[name] + i]

    # the same level data as the BBC has it (the debug jump patches the lifts), the same level and place
    for L in range(12):
        base = 0x5700 - 0x100 * L
        for k in range(256):
            m[0xe000 + L * 256 + k] = bbc.m[base + k]
    level = bbc.m[0x9f]
    px = bbc.m[0x93]
    pcol, py = bbc_place(bbc)
    m[lb["init_px"]] = bbc.m[0xf8 + 0] if False else (0xf8 if px >= 0x80 else 4)
    m[lb["arrive_mode"]] = 0
    c.a = level
    call_a = level
    sav = (c.pc, c.a, c.x, c.y, c.sp)
    c.push((0x0200 - 1) >> 8)
    c.push((0x0200 - 1) & 255)
    c.pc = lb["set_level"]
    c.a = level
    while c.pc != 0x0200:
        c.step()
    c.pc, c.a, c.x, c.y, c.sp = sav
    for name in ("px", "pc"):
        setn(name, px if name == "px" else pcol)
    setn("py", py)
    setn("pdir", bbc.m[0x94])
    setn("pstance", bbc.m[0x6d])
    setn("pframe", bbc.m[0x92])
    for k in range(16):
        setn("carried", bbc.m[0xc0 + k], k)
    for nm, a in (("suit_energy", 0x6f), ("blaster_energy", 0x5b), ("lives", 0x5a)):
        setn(nm, bbc.m[a])
    setn("jp_energy", bbc.m[0xe2])
    setn("maxjump", bbc.m[0xe3])
    setn("frame_counter", bbc.m[0x5e])
    setn("nmines", bbc.m[0x60])
    # the enemies: the BBC's, as they stand
    last = bbc.m[0x7f]
    setn("last_enemy", last)
    for i in range(last):
        setn("enemies", bbc.m[0x04 + i], i)
    c.pc = 0x0200        # (the idle machine is never run again)
    m[lb["enemy_fire"]] = 0x60                               # no firing
    # (the objects collected so far)
    for k in range(48):
        setn("objflags", bbc.m[0x03a0 + k] if False else bbc.m[0x03a0 + k], k)
    held = []
    script_len = 0
    held_for = 0
    synced = 0
    hist = []
    for i in range(iterations):
        if held_for <= 0:
            held = rnd.sample(POOL, rnd.choice([0, 1, 1, 2]))
            held_for = rnd.randrange(2, 20)
        held_for -= 1
        if os.environ.get("DEBUG_IT") == str(i):
            pcx, pyy = getn("pc"), getn("py")
            print("PRE iteration %d: native pc %d py %d dir %d stance %d; BBC place %s" % (i, pcx, pyy, getn("pdir"), getn("pstance"), bbc_place(bbc)))
            for col in (pcx - 1, pcx, pcx + 1, pcx + 2, pcx + 3):
                print("  col %d native lines %d.. %s" % (col, pyy - 8, [m[0xee00 + (l & 7) * 256 + m[0xa000 + (l >> 3) * 256 + col]] for l in range(pyy - 8, pyy + 40, 2)]))
                st0 = bbc.screen_start()
                left0 = bbc.m[0x86] + bbc.m[0x84]
                def bb(c_, l_):
                    a_ = st0 + (l_ >> 3) * 256 + (c_ - left0) * 8 + (l_ & 7)
                    if a_ >= 0x8000:
                        a_ -= 0x2000
                    return bbc.m[a_]
                print("  col %d bbc    lines %d.. %s" % (col, pyy - 8, [bb(col, l) for l in range(pyy - 8, pyy + 40, 2)]))
        if os.environ.get("DEBUG_IT") == str(i):
            for ln in (pyy + 28, pyy + 33):
                print("  line %d cols %d..%d native %s" % (ln, pcx - 4, pcx + 3, [m[0xee00 + (ln & 7) * 256 + m[0xa000 + (ln >> 3) * 256 + c_]] for c_ in range(pcx - 4, pcx + 4)]))
                print("  line %d cols %d..%d bbc    %s" % (ln, pcx - 4, pcx + 3, [bb(c_, ln) for c_ in range(pcx - 4, pcx + 4)]))
        if os.environ.get("DEBUG_IT") == str(i):
            print("  native ROWS rows 24-28 cols 214..221:", [[m[0xa000 + r_ * 256 + c_] for c_ in range(214, 222)] for r_ in range(24, 29)])
            for c_ in (216, 217, 218):
                print("  col %d lines 192..223: native %s" % (c_, [m[0xee00 + (l_ & 7) * 256 + m[0xa000 + (l_ >> 3) * 256 + c_]] for l_ in range(192, 224)]))
                print("  col %d lines 192..223: bbc    %s" % (c_, [bb(c_, l_) for l_ in range(192, 224)]))
            for l_ in (209, 212, 216, 220):
                print("  line %d cols 214..226 bbc %s" % (l_, [bb(c_, l_) for c_ in range(214, 227)]))
            bad_ = []
            for r_ in range(32):
                for c_ in range(left0 + 1, left0 + 31):
                    bb_ = [bb(c_, r_ * 8 + k_) for k_ in range(8)]
                    nb_ = [m[0xee00 + k_ * 256 + m[0xa000 + r_ * 256 + c_]] for k_ in range(8)]
                    if bb_ != nb_:
                        bad_.append((c_, r_))
            print("  cells differing between the BBC's screen and the native ROWS: %d: %s" % (len(bad_), bad_[:40]))
            print("  tile data col 48..50 bbc %s native %s" % ([[hex(bbc.m[0x5700 - 0x100 * getn("level") + c_ * 4 + k_]) for k_ in range(4)] for c_ in (48, 49, 50)], [[hex(m[0xe000 + getn("level") * 256 + c_ * 4 + k_]) for k_ in range(4)] for c_ in (48, 49, 50)]))
            print("  native enemies:", [[getn("enemies", e * 5 + j) for j in range(5)] for e in range(getn("last_enemy") // 5)], "pool", [getn("pool_owner", j) for j in range(4)], "mines", [(getn("mines_x", j), getn("mines_y", j), getn("mines_state", j)) for j in range(6)])
        if os.environ.get("DEBUG_FROM") and i >= int(os.environ["DEBUG_FROM"]):
            eo_ = int(os.environ.get("DEBUG_ENEMY", "9")) * 5
            print("it %d: enemy %s pool_owner %s pg_col %s pg_row %s pg_img %s cells27 %s under3 %s" % (i, [getn("enemies", eo_ + j) for j in range(5)], [getn("pool_owner", j) for j in range(4)], [getn("pg_col", j) for j in range(4)], [getn("pg_row", j) for j in range(4)], [getn("pg_img", j) for j in range(4)], [m[0xa000 + 27 * 256 + c_] for c_ in range(216, 219)], [getn("pool_under", 36 + j) for j in range(12)]))
        if os.environ.get("DEBUG_UNDER"):
            g_ = int(os.environ["DEBUG_UNDER"])
            u_ = [getn("pool_under", g_ * 12 + j) for j in range(12)]
            if any(v >= 204 for v in u_) and not hasattr(main, "seen"):
                main.seen = True
                print("it %d: first bad under group %d: %s pool_owner %s pg_col %s pg_row %s px %d" % (i, g_, u_, [getn("pool_owner", j) for j in range(4)], [getn("pg_col", j) for j in range(4)], [getn("pg_row", j) for j in range(4)], getn("px")))
        bbc.set_keys(*held)
        bbc.m[0xfe64] = 1
        bbc.cpu.step()
        while bbc.cpu.pc != loop:
            bbc.cpu.step()
        # (the BBC has taken its step: the debug listing is of the cells before it, from the native's)
        # the native step with the same keys
        nums = [NATIVE_KEY[k] for k in held]
        setn("key1", nums[-1] if nums else 0)
        setn("key2", nums[0] if nums else 0)
        if os.environ.get("DEBUG_BL") and i >= int(os.environ["DEBUG_BL"]):
            print("it %d keys %s native bullets ttl %s c %s l %s dir %s | bbc ttl %s" % (i, held, [getn("bl_ttl", j) for j in range(6)], [getn("bl_c", j) for j in range(6)], [getn("bl_l", j) for j in range(6)], [getn("bl_dir", j) for j in range(6)], [bbc.m[0x39 + 4 * j] for j in range(6)]))
        if os.environ.get("DEBUG_WATCHE") == str(i):
            tgt = lb["enemies"] + int(os.environ.get("DEBUG_WATCHE_OFF", "49"))
            inv2 = {v_: k_ for k_, v_ in lb.items() if not k_.startswith("@")}
            def hook2(a_, v_, tgt=tgt):
                if a_ == tgt:
                    near = max((x_ for x_ in inv2 if x_ <= c.pc), default=0)
                    print("   write enemies+%d = %d pc %04x near %s+%d" % (tgt - lb["enemies"], v_, c.pc, inv2.get(near), c.pc - near))
                    st_ = [m[0x100 + c.sp + 1 + 2 * k_] | m[0x100 + c.sp + 2 + 2 * k_] << 8 for k_ in range(5)]
                    print("   stack returns:", [("%04x" % (x_ + 1), inv2.get(max((y_ for y_ in inv2 if y_ <= x_ + 1), default=0))) for x_ in st_])
            c.write_hooks.append(hook2)
        if os.environ.get("DEBUG_WATCH") == str(i):
            lo = lb["pool_under"] + 36
            inv = {v_: k_ for k_, v_ in lb.items() if not k_.startswith("@")}
            def hook(a_, v_, lo=lo):
                if lo <= a_ < lo + 12:
                    near = max((x_ for x_ in inv if x_ <= c.pc), default=0)
                    print("   write pool_under+%d = %d pc %04x near %s+%d" % (a_ - lo + 36, v_, c.pc, inv.get(near), c.pc - near))
            c.write_hooks.append(hook)
        call("game_step")
        if os.environ.get("DEBUG_WATCH") == str(i):
            c.write_hooks.pop()
        call("smooth")
        call("calc_scroll")
        # compare
        diffs = []
        bplace = bbc_place(bbc)
        nplace = (getn("pc"), getn("py"))
        if bplace != nplace:
            diffs.append(("place", bplace, nplace))
        for name, a in ZP.items():
            bv, nv = bbc.m[a], getn(NAT[name])
            if bv != nv:
                diffs.append((name, bv, nv))
        for k in range(16):
            if bbc.m[0xc0 + k] != getn("carried", k):
                diffs.append(("carried%d" % k, bbc.m[0xc0 + k], getn("carried", k)))
        bl = bbc.m[0x7f]
        for e in range(0, bl, 5):
            b5 = [bbc.m[0x04 + e + j] for j in range(5)]
            n5 = [getn("enemies", e + j) for j in range(5)]
            b5[2] &= 0x0f
            n5[2] &= 0x0f
            if b5[0] >= 0x80:
                b5[4] = n5[4] = 0              # (a removed enemy's energy byte is whatever the BBC loop left)
            if b5 != n5:
                diffs.append(("enemy%d" % (e // 5), b5, n5))
                break
        hist.append((i, list(held), bplace, nplace, bbc.m[0x6d], bbc.m[0x8f], bbc.m[0x96], bbc.m[0x95], bbc.m[0x92], getn("pstance"), getn("pjf"), getn("jump_timer"), getn("jump_direction"), getn("pframe"), bbc.m[0x60], getn("nmines"), bbc.m[0x6b], getn("clim_cd")))
        if diffs:
            print("iteration %d (keys %s): the games differ: %s" % (i, held, diffs[:6]))
            # the bytes of the column to the right of the player, and above, in both
            bm_ = bbc.m
            start = bbc.screen_start()
            left = bm_[0x86] + bm_[0x84]
            def bbyte(col, line):
                a = start + (line >> 3) * 256 + (col - left) * 8 + (line & 7)
                if a >= 0x8000:
                    a -= 0x2000
                return bm_[a]
            def nbyte(col, line):
                ch = m[0xa000 + (line >> 3) * 256 + col]
                return m[0xee00 + (line & 7) * 256 + ch]
            for col in (bplace[0] + 3, bplace[0], bplace[0] + 1):
                print("   col %d lines 120..163 bbc %s" % (col, [bbyte(col, l) for l in range(120, 164, 2)]))
                print("   col %d lines 120..163 nat %s" % (col, [nbyte(col, l) for l in range(120, 164, 2)]))
            print("   bbc mines x %s y %s st %s" % ([bbc.m[0x02ea + k] for k in range(6)], [bbc.m[0x02f0 + k] for k in range(6)], [bbc.m[0x02f6 + k] for k in range(6)]))
            print("   nat mines x %s y %s st %s" % ([getn("mines_x", k) for k in range(6)], [getn("mines_y", k) for k in range(6)], [getn("mines_state", k) for k in range(6)]))
            print("   nat ROWS rows 14-16 cols 232-236: %s" % [[m[0xa000 + r * 256 + c] for c in range(232, 237)] for r in (14, 15, 16)])
            pcx, pyy = nplace
            for ln in (pyy + 28, pyy + 33):
                print("   line %d cols %d..%d: bbc %s nat %s" % (ln, pcx - 4, pcx + 3, [bbyte(c_, ln) for c_ in range(pcx - 4, pcx + 4)], [nbyte(c_, ln) for c_ in range(pcx - 4, pcx + 4)]))
            print("   nat line 156 cols 214..217 %s ; line 161 cols 211..216 %s ; line 157..161 col 215 %s" % ([nbyte(c_, 156) for c_ in range(214, 218)], [nbyte(c_, 161) for c_ in range(211, 217)], [nbyte(215, l_) for l_ in range(157, 162)]))
            print("   pdir bbc %d nat %d ; address bbc low %02x high %02x" % (bbc.m[0x94], getn("pdir"), bbc.m[0x90], bbc.m[0x91]))
            for h in hist[-8:]:
                print("   it %d keys %s bbc place %s native %s | bbc st %d jf %d jt %d jd %d fr %d | native st %d jf %d jt %d jd %d fr %d | mines bbc %d native %d | cd bbc %d native %d" % h)
            return 1
        if os.environ.get("DEBUG_ECELLS") and not hasattr(main, "ecell"):
            st1 = bbc.screen_start()
            left1 = bbc.m[0x86] + bbc.m[0x84]
            bad_ = []
            for r_ in range(12, 16):
                for c_ in range(234, 237):
                    a_ = st1 + r_ * 256 + (c_ - left1) * 8
                    if a_ >= 0x8000:
                        a_ -= 0x2000
                    bb_ = [bbc.m[a_ + k_] for k_ in range(8)]
                    nb_ = [m[0xee00 + k_ * 256 + m[0xa000 + r_ * 256 + c_]] for k_ in range(8)]
                    if bb_ != nb_:
                        bad_.append((c_, r_, bb_, nb_))
            if bad_ and left1 + 32 > 237 and left1 < 233:
                main.ecell = True
                print("it %d: enemy cells differ (BBC window %d..): player %s keys %s: %s" % (i, left1, bplace, held, bad_[:3]))
        synced += 1
    print("%d iterations: the player's state and the enemies agreed throughout (level %d, x %d, carried %s, score %s)"
          % (synced, getn("level"), getn("px"), [getn("carried", k) for k in range(16)], [getn("score", k) for k in range(8)]))
    return 0


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    sys.exit(main(n, seed, int(sys.argv[3]) if len(sys.argv) > 3 else 0))
