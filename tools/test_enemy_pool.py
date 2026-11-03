#!/usr/bin/env python3
"""Check new-game spawn side and enemy character groups on crowded levels.
Run after `make`: test_enemy_pool.py.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "tools"))
from sim_check import Machine, labels  # noqa: E402


def main():
    mc = Machine()
    c, m = mc.cpu, mc.cpu.m
    sym = labels(os.path.join(HERE, "..", "build", "c64", "game.lbl"))
    sentinel = 0x0200
    m[sentinel : sentinel + 3] = bytes((0x4C, sentinel & 255, sentinel >> 8))
    m[0xD01A] = 0

    def call(name):
        c.push((sentinel - 1) >> 8)
        c.push((sentinel - 1) & 255)
        c.pc = sym[name]
        steps = 0
        while c.pc != sentinel and steps < 5_000_000:
            c.step()
            steps += 1
        if c.pc != sentinel:
            raise AssertionError("%s did not return" % name)

    call("new_game")
    if (m[sym["px"]], m[sym["pc"]], m[sym["pdir"]]) != (196, 196, 0):
        raise AssertionError("new game should start where the BBC game does (x 196)")

    starts = sym["level_tiles0"]
    for level in range(12):
        source = starts + level * 256
        target = 0xE000 + level * 256
        m[target : target + 256] = m[source : source + 256]

    offsets = sym["level_enemy_offsets"]
    for level in (1, 2):
        m[sym["level"]] = level
        call("load_level")
        call("pool_configure")
        call("pool_reset")
        base = m[sym["nchars"]]
        groups = m[sym["pool_groups"]]
        enemy_start = m[offsets + level]
        enemy_end = m[offsets + level + 1]
        enemy_count = enemy_end - enemy_start
        if groups < enemy_count:
            raise AssertionError(
                "level %d has %d enemies but only %d character groups"
                % (level + 1, enemy_count, groups)
            )

        level_glyphs = bytes(
            m[0xEE00 + line * 256 + char]
            for char in range(1, base)
            for line in range(8)
        )
        for i in range(enemy_count):
            m[sym["enemy_to_update"]] = i * 5
            m[sym["ev_col"]] = 4 + i * 4
            m[sym["ev_y"]] = 2
            m[sym["ev_dir"]] = i & 1
            m[sym["zv"]] = 0
            call("draw_enemy")

        owners = [m[sym["pool_owner"] + i] for i in range(10)]
        if sum(owner != 0xFF for owner in owners) != enemy_count:
            raise AssertionError("not every level %d enemy got a drawing group" % (level + 1))
        after = bytes(
            m[0xEE00 + line * 256 + char]
            for char in range(1, base)
            for line in range(8)
        )
        if after != level_glyphs:
            raise AssertionError("enemy graphics overwrote level %d glyphs" % (level + 1))
        for i in range(enemy_count):
            char = m[0xA000 + 8 * 256 + 4 + i * 4]
            group = (char - base) // 12
            if not 0 <= group < groups or owners[group] != i * 5:
                raise AssertionError("level %d enemy %d was not drawn from its group" % (level + 1, i))

    print("PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
