#!/usr/bin/env python3
"""Unit checks for the 65816 interpreter, using code assembled by ca65."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from asm65816 import assemble
from op65816 import OPCODES
from sim65816 import Sim65816, Unsupported, C, N, V, Z


def run(src, setup=None, origin=0x0800):
    s = Sim65816()
    code = assemble(src, origin)
    s.mem[origin:origin + len(code)] = code
    s.pc = origin
    if setup:
        setup(s)
    s.run(10000)
    return s


# every opcode has a handler, apart from the ones the simulator documents as unsupported
missing = sorted({n for n, _ in OPCODES.values() if not hasattr(Sim65816, "op_" + n)})
assert missing == ["COP", "STP", "WAI", "WDM"] or missing == sorted(["BRK", "COP", "STP", "WAI", "WDM"]), missing

# mode switching: emulation -> native, REP/SEP, 16-bit load, flags
s = run("clc\nxce\nrep #$30\nlda #$8001\nldx #$1234\nh: bra h")
assert s.e == 0 and s.c == 0x8001 and s.x == 0x1234 and not s.p & N and not s.p & Z   # flags follow the last load (LDX)
s = run("clc\nxce\nrep #$30\nsep #$30\nlda #$ff\nldx #$ff\nh: bra h")
assert s.m8 and s.x8 and s.c == 0x00FF
# back to emulation forces 8-bit and clears the index high bytes
s = run("clc\nxce\nrep #$30\nldx #$1234\nsec\nxce\nh: bra h")
assert s.e == 1 and s.x == 0x34 and s.sp >> 8 == 1

# 16-bit ADC: carry out and signed overflow
s = run("clc\nxce\nrep #$30\nclc\nlda #$7fff\nadc #$0001\nh: bra h")
assert s.c == 0x8000 and s.p & V and not s.p & C and s.p & N
s = run("clc\nxce\nrep #$30\nclc\nlda #$ffff\nadc #$0001\nh: bra h")
assert s.c == 0 and s.p & C and s.p & Z and not s.p & V
# SBC borrow
s = run("clc\nxce\nrep #$30\nsec\nlda #$0000\nsbc #$0001\nh: bra h")
assert s.c == 0xFFFF and not s.p & C and s.p & N
# 8-bit accumulator in native mode leaves B alone
s = run("clc\nxce\nrep #$30\nlda #$1200\nsep #$20\nlda #$34\nh: bra h")
assert s.c == 0x1234

# compare and branch
s = run("clc\nxce\nrep #$30\nldx #5\nl: dex\ncpx #2\nbne l\nh: bra h")
assert s.x == 2

# block move forward replicates a pattern (the boot block's trick); DBR becomes the destination bank
def seed(s):
    s.mem[0xE12000:0xE12004] = bytes([1, 2, 3, 4])
s = run("clc\nxce\nrep #$30\nldx #$2000\nldy #$2004\nlda #11\nmvn $e10000,$e10000\nh: bra h", seed)
assert bytes(s.mem[0xE12000:0xE1200C]) == bytes([1, 2, 3, 4] * 3) and s.dbr == 0xE1
assert s.c == 0xFFFF and s.x == 0x200C and s.y == 0x2010
# MVP copies downwards
def seed2(s):
    s.mem[0x0200:0x0204] = bytes([9, 8, 7, 6])
s = run("clc\nxce\nrep #$30\nldx #$0203\nldy #$0303\nlda #3\nmvp $000000,$000000\nh: bra h", seed2)
assert bytes(s.mem[0x0300:0x0304]) == bytes([9, 8, 7, 6])

# subroutines and the stack: JSR/RTS (address of last operand byte is pushed), JSL/RTL (bank first)
s = run("clc\nxce\nrep #$30\nlda #0\njsr sub\nh: bra h\nsub: inc a\nrts")
assert s.c == 1
src = "clc\nxce\nrep #$30\nlda #0\njsl $000810\nh: bra h\n"
code = assemble(src)
pad = bytes(0x10 - len(code))
code = code + pad + bytes([0x1A, 0x6B])               # at $0810: INC A ; RTL
s = Sim65816()
s.mem[0x0800:0x0800 + len(code)] = code
s.pc = 0x0800
s.run(1000)
assert s.c == 1 and s.sp == 0x01FF, hex(s.sp)

# stack pushes and pulls, direct page and long-indexed addressing
s = run("clc\nxce\nrep #$30\nlda #$abcd\npha\npea $1234\nplx\nply\nh: bra h")
assert s.x == 0x1234 and s.y == 0xABCD and s.sp == 0x01FF
def seed3(s):
    s.mem[0x0510:0x0512] = bytes([0x56, 0x34])
s = run("clc\nxce\nrep #$30\nlda #$0500\ntcd\nlda $10\nldx #2\nsta $e10010,x\nh: bra h", seed3)
assert s.c == 0x3456 and s.mem[0xE10012] == 0x56 and s.mem[0xE10013] == 0x34
# the soft switch address is a plain read-modify-write register
s = run("clc\nxce\nsep #$20\nlda $e0c029\nora #$c0\nsta $e0c029\nh: bra h", lambda s: s.io.update({(0xE0, 0xC029): 0x01}))
assert s.io[(0xE0, 0xC029)] == 0xC1

# emulation mode with the direct page at $0000: zero-page indexing and pointers wrap within page 0 like the 6502
def seed4(s):
    s.mem[0x0001] = 0x77            # $ff + 2 wraps to $01
    s.mem[0x0102] = 0x11            # (not $0101: no carry into page 1)
    s.mem[0x00ff] = 0x40            # pointer low byte at $ff; its high byte wraps to $00
    s.mem[0x0000] = 0x12            # high byte -> pointer $1240
    s.mem[0x1240 + 3] = 0x5a
s = run("ldx #2\nlda $ff,x\nsta $0300\nldy #3\nlda ($ff),y\nsta $0301\nh: bra h", seed4)
assert s.mem[0x0300] == 0x77 and s.mem[0x0301] == 0x5a, (s.mem[0x0300], s.mem[0x0301])
# in native mode it does not wrap
s = run("clc\nxce\nrep #$30\nldx #2\nlda $ff,x\nsta $0300\nh: bra h", lambda s: s.mem.__setitem__(slice(0x101, 0x103), bytes([0x66, 0x66])))
assert s.mem[0x0300] == 0x66 and s.mem[0x0301] == 0x66

# an unsupported instruction stops the run instead of being skipped
try:
    run("wai")
    raise AssertionError("WAI should be unsupported")
except Unsupported:
    pass
print("sim65816 OK")
