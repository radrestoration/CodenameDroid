#!/usr/bin/env python3
"""Exercise the visible lift ride and the next-level display handoff.
Run after `make`: test_lift.py.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "tools"))
from sim_check import Machine, labels  # noqa: E402
import bbcmem  # noqa: E402


def main():
    mc = Machine(True)
    c, m = mc.cpu, mc.cpu.m
    sym = labels(os.path.join(HERE, "..", "build", "c64", "game.lbl"))
    for _ in range(120):
        mc.run_frame()

    sentinel = 0x0800
    m[sentinel : sentinel + 3] = bytes((0x4C, sentinel & 255, sentinel >> 8))

    def call(name, a=None):
        c.push((sentinel - 1) >> 8)
        c.push((sentinel - 1) & 255)
        if a is not None:
            c.a = a
        c.pc = sym[name]
        for _ in range(200):
            mc.run_frame()
            if c.pc == sentinel:
                return
        raise AssertionError("%s did not return" % name)

    call("new_game")
    m[sym["newlvl"]] = 1
    m[sym["lift_dir"]] = 1
    call("lift_ride_scroll")
    if m[sym["lift_screen"]] != 1 or m[0xD018] not in (0x24, 0x34):
        raise AssertionError("the lift display was not left active")
    ride_matrix = bytes(m[0xC800:0xD000])
    ride_charset = bytes(mc.shadow[:0x800])
    if any(ride_charset[:8]) or m[1] != 0x35:
        raise AssertionError("the ride's blank character is not blank, or the memory map was left changed")

    call("set_level", 1)
    if m[sym["lift_screen"]] != 1 or m[0xD018] not in (0x24, 0x34):
        raise AssertionError("the next-level rebuild replaced the lift display")
    if bytes(m[0xC800:0xD000]) != ride_matrix or bytes(mc.shadow[:0x800]) != ride_charset:
        raise AssertionError("the next-level rebuild overwrote the visible ride")

    staged_charset = bytes(mc.shadow[0x800:0x1000])
    call("lift_finish_view")
    if m[sym["lift_screen"]] != 0:
        raise AssertionError("the display handoff did not finish")
    if m[0xD018] not in (0x20, 0x30) or m[0xDD00] & 3:
        raise AssertionError("the main VIC bank or display was not restored")
    if any(staged_charset[:8]):
        raise AssertionError("the staged blank character is not blank")
    if bytes(m[0xC000:0xC800]) != staged_charset:
        raise AssertionError("the rebuilt level charset was not restored from staging")
    if m[sym["p_spr_base"]] != 0x40 or m[sym["rows_page"]] != 0xA0:
        raise AssertionError("the main sprite or row layout was not restored")

    if m[sym["cur_buf"]] > 1:
        raise AssertionError("the displayed buffer number is not 0 or 1")

    bbc = bbcmem.load()
    samples = ((4, 3, 9), (0, 3, 10), (3, 3, 12), (46, 1, 13))

    def check_surface(after_lift):
        tile_numbers = (0x10, 0x0F, 0x16, 0x14) if after_lift else (0x35, 0x34, 0x36, 0x37)
        for (col, row, nibble), tile in zip(samples, tile_numbers):
            tile_byte = m[0xE000 + col * 4 + row // 2]
            if (tile_byte >> (4 * (row & 1))) & 15 != nibble:
                raise AssertionError("surface test sampled the wrong tile")
            for x in range(4):
                cells = bbcmem.tile_cell_column(bbc, tile, x)
                for y, expected in enumerate(cells):
                    ch = m[0xA000 + (row * 4 + y) * 256 + col * 4 + x]
                    actual = bytes(m[0xC000 + ch * 8:0xC008 + ch * 8])
                    converted = bytes(m[sym["conv_table"] + b] for b in expected)
                    if actual != converted:
                        raise AssertionError("surface nibble %x at %d,%d cell %d,%d does not match BBC tile %02x: %s != %s" %
                                             (nibble, col, row, x, y, tile, actual.hex(), converted.hex()))

    call("new_game")
    check_surface(False)
    m[sym["px"]] = 248
    m[sym["pdir"]] = 0
    m[sym["lift_dir"]] = 1
    call("lift_ride")
    if m[sym["level"]] != 0 or [m[sym["level_xlat"] + n] for n in (9, 10, 12, 13)] != [0x10, 0x0F, 0x16, 0x14]:
        raise AssertionError("an attempted lift without a pass did not change the surface tiles")
    call("new_game")
    check_surface(False)
    m[sym["carried"]] = 2
    for level, side, direction in ((1, 248, 1), (2, 4, 1), (1, 4, 0), (0, 4, 0)):
        m[sym["px"]] = side
        m[sym["pc"]] = side
        m[sym["pdir"]] = 0 if side == 248 else 1
        m[sym["lift_dir"]] = direction
        m[sym["py"]] = 96
        call("lift_ride")
        if m[sym["level"]] != level:
            raise AssertionError("lift did not reach level %d" % level)
        if level == 2:
            m[sym["px"]] = 0x23
            m[sym["py"]] = 0xB8
            m[sym["obst_y"]] = 0x10
            call("consider_collecting_object_to_right")
            if m[sym["objflags"] + 8] != 0x31 or m[sym["carried"]] != 6:
                raise AssertionError("level 3 chest did not give six passes")
    check_surface(True)
    if m[sym["overflow"]]:
        raise AssertionError("surface character set overflowed")
    call("save_game")
    call("new_game")
    check_surface(False)
    m[sym["deepest"]] = 1
    call("jump_to_saved")
    m[sym["init_px"]] = 4
    call("set_level", 0)
    check_surface(True)
    call("new_game")
    check_surface(False)

    print("PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
