#!/usr/bin/env python3
"""Exercise the visible lift ride and the next-level display handoff.
Run after `make`: test_lift.py.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "tools"))
from sim_check import Machine, labels  # noqa: E402


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

    print("PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
