"""Minimal headless 65C816 interpreter for unit-testing the Apple IIgs code without an emulator.

What it models: the full opcode set (table in op65816.py), emulation and native mode, 8/16-bit
accumulator and index registers, direct page, data bank and program bank, the stack in bank 0, block
moves, and a flat 16 MB memory. Instruction counts only: no cycle timing.

What it does not model (it stops or ignores, and says so): decimal-mode ADC/SBC (raises), BRK/COP/STP/WAI/WDM
(raise), interrupts, the IIgs memory shadowing, bank-0/1 vs E0/E1 mapping, and the emulation-mode quirk
(page-1 stack wrap on indexed addressing). Soft switches ($C000-$C0FF in banks
$00/$01/$E0/$E1) are plain bytes in `io` that the test can read and write.
"""
from op65816 import OPCODES

N, V, M, X, D, I, Z, C = 0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01


class Unsupported(Exception):
    pass


# ---- an ESTIMATE of the cycles an instruction takes (the WDC data sheet's table as I know it: not checked against hardware or
# GSplus's own counts; no wait states for slow memory, no page-crossing penalties except the 16-bit index case)
_READ = {"LDA", "LDX", "LDY", "ADC", "SBC", "AND", "ORA", "EOR", "CMP", "CPX", "CPY", "BIT"}
_STORE = {"STA", "STX", "STY", "STZ"}
_RMW = {"INC", "DEC", "ASL", "LSR", "ROL", "ROR", "TSB", "TRB"}
_BASE = {"imm": 2, "dp": 3, "dpx": 4, "dpy": 4, "abs": 4, "abx": 4, "aby": 4, "long": 5, "lgx": 5, "ind": 5, "inx": 6,
         "iny": 5, "inl": 6, "ily": 6, "sr": 4, "sry": 7}
_FIXED = {"JSR": 6, "JSL": 8, "RTS": 6, "RTL": 6, "RTI": 7, "JMP": 3, "JML": 4, "PHA": 3, "PHX": 3, "PHY": 3, "PHP": 3,
          "PHB": 3, "PHK": 3, "PHD": 4, "PLA": 4, "PLX": 4, "PLY": 4, "PLP": 4, "PLB": 4, "PLD": 5, "PEA": 5, "PEI": 6,
          "PER": 6, "REP": 3, "SEP": 3, "XBA": 3, "BRA": 3, "BRL": 4, "BRK": 7, "WAI": 3}


def cycles_estimate(name, mode, m8, x8):
    if name in _FIXED:
        c = _FIXED[name]
        if name in ("PHA", "PLA") and not m8 or name in ("PHX", "PHY", "PLX", "PLY") and not x8:
            c += 1
        if name == "JMP" and mode == "abi":
            c = 5
        if name == "JMP" and mode == "aix":
            c = 6
        return c
    if mode == "rel":
        return 2
    if name in _READ or name in _STORE:
        c = _BASE.get(mode, 3)
        wide = not (x8 if name in ("LDX", "LDY", "CPX", "CPY", "STX", "STY") else m8)
        if wide:
            c += 1
        if name in _READ and not x8 and mode in ("abx", "aby", "iny"):
            c += 1
        if name in _STORE and mode in ("abx", "aby"):
            c += 1
        if name in _STORE and mode in ("ind", "iny", "ily", "inl", "inx") and mode != "inx":
            c += 1
        return c
    if name in _RMW:
        if mode == "acc":
            return 2
        c = {"dp": 5, "dpx": 6, "abs": 6, "abx": 7}.get(mode, 6)
        return c + (0 if m8 else 2)
    return 2


class Sim65816:
    def __init__(self):
        self.mem = bytearray(1 << 24)
        self.io = {}                    # (bank, $C0xx) -> byte, for banks 00/01/E0/E1
        self.c = 0                      # 16-bit accumulator (A low, B high)
        self.x = self.y = 0
        self.sp = 0x01FF
        self.dp = 0
        self.dbr = self.pbr = 0
        self.pc = 0
        self.p = M | X | I              # flags N V M X D I Z C
        self.e = 1
        self.count = 0                  # instructions executed (a block move counts as one)
        self.cycles = 0                 # an ESTIMATE of the cycles (see cycles_estimate)
        self.moved = 0                  # bytes moved by MVN/MVP
        self.io[(0xE0, 0xC035)] = 0x08  # shadow register: SHR shadowing inhibited, as at power-on
        self.mem[0xE0C035] = 0x08       # (where it is when a test turns the I/O window off)

    # ---- memory -------------------------------------------------------------------------------
    def _io(self, a):
        return (a >> 16) in (0x00, 0x01, 0xE0, 0xE1) and 0xC000 <= (a & 0xFFFF) <= 0xC0FF

    # The Apple II softswitches RAMRD ($C002/$C003) and RAMWRT ($C004/$C005) send reads / writes of bank 0 $0200-$BFFF to bank 1;
    # a write that lands in bank 1 $2000-$9FFF is also made in bank $E1 unless bit 3 of the shadow register ($C035) is set
    # (Apple IIgs Technical Note #70; GSplus moremem.c fixup_ramwrt). ALTZP, language card and the other shadow bits are not modelled.
    ramrd = False
    ramwrt = False

    def rd(self, a):
        a &= 0xFFFFFF
        if a < 0x10000:
            if self.ramrd and 0x0200 <= a < 0xC000:
                a |= 0x10000
        if self._io(a):
            return self.io.get((a >> 16, a & 0xFFFF), 0)
        return self.mem[a]

    def wr(self, a, v):
        a &= 0xFFFFFF
        if a < 0x10000 and self.ramwrt and 0x0200 <= a < 0xC000:
            a |= 0x10000
        if a >> 16 == 0xE0 and 0xC002 <= (a & 0xFFFF) <= 0xC005:
            if a & 0xFFFF < 0xC004:                      # (also with the I/O window turned off: bank $E0 is never data)
                self.ramrd = bool(a & 1)
            else:
                self.ramwrt = bool(a & 1)
        if self._io(a):
            self.io[(a >> 16, a & 0xFFFF)] = v & 0xFF
        else:
            self.mem[a] = v & 0xFF
            if 0x012000 <= a < 0x01A000 and not self._shadow_reg() & 0x08:
                self.mem[a | 0xE00000] = v & 0xFF

    def _shadow_reg(self):
        return self.io.get((0xE0, 0xC035), 0) if self._io(0xE0C035) else self.mem[0xE0C035]

    def rd16(self, a): return self.rd(a) | (self.rd(a + 1) << 8)
    def rd24(self, a): return self.rd16(a) | (self.rd(a + 2) << 16)

    def wr16(self, a, v):
        self.wr(a, v)
        self.wr(a + 1, v >> 8)

    def fetch(self):
        v = self.rd((self.pbr << 16) | self.pc)
        self.pc = (self.pc + 1) & 0xFFFF
        return v

    def fetch16(self):
        lo = self.fetch()
        return lo | (self.fetch() << 8)

    def fetch24(self):
        lo = self.fetch16()
        return lo | (self.fetch() << 16)

    # ---- registers ----------------------------------------------------------------------------
    @property
    def m8(self): return self.e or bool(self.p & M)

    @property
    def x8(self): return self.e or bool(self.p & X)

    @property
    def a(self): return self.c & 0xFF if self.m8 else self.c

    def set_a(self, v):
        self.c = (self.c & 0xFF00) | (v & 0xFF) if self.m8 else v & 0xFFFF

    def set_x(self, v): self.x = v & (0xFF if self.x8 else 0xFFFF)
    def set_y(self, v): self.y = v & (0xFF if self.x8 else 0xFFFF)

    def flag(self, bit, on): self.p = (self.p | bit) if on else (self.p & ~bit)

    def nz(self, v, eight):
        v &= 0xFF if eight else 0xFFFF
        self.flag(Z, v == 0)
        self.flag(N, v & (0x80 if eight else 0x8000))
        return v

    def set_p(self, v):
        self.p = v & 0xFF
        if self.e:
            self.p |= M | X
        elif self.p & X:
            self.x &= 0xFF
            self.y &= 0xFF

    # ---- stack (bank 0) -----------------------------------------------------------------------
    def push(self, v):
        self.wr(self.sp, v)
        self.sp = ((self.sp - 1) & 0xFF) | 0x100 if self.e else (self.sp - 1) & 0xFFFF

    def pull(self):
        self.sp = ((self.sp + 1) & 0xFF) | 0x100 if self.e else (self.sp + 1) & 0xFFFF
        return self.rd(self.sp)

    def push16(self, v):
        self.push(v >> 8)
        self.push(v)

    def pull16(self):
        lo = self.pull()
        return lo | (self.pull() << 8)

    # ---- effective addresses ------------------------------------------------------------------
    def dpa(self, off):
        """Direct-page address of `off` (offset plus any index already added). In emulation mode with the
        direct page at a page boundary (DL = 0) the offset wraps within the page, as on the 6502."""
        if self.e and not self.dp & 0xFF:
            return (self.dp + (off & 0xFF)) & 0xFFFF
        return (self.dp + off) & 0xFFFF

    def dp_ptr16(self, off):
        """A 16-bit pointer stored at direct-page offset `off` (its high byte wraps like the 6502's)."""
        return self.rd(self.dpa(off)) | (self.rd(self.dpa(off + 1)) << 8)

    def dp_ptr24(self, off):
        return self.dp_ptr16(off) | (self.rd(self.dpa(off + 2)) << 16)

    def ea(self, mode):
        """24-bit effective address for a memory operand."""
        idx_x = self.x
        idx_y = self.y
        if mode == 'abs':
            return (self.dbr << 16) | self.fetch16()
        if mode == 'abx':
            return ((self.dbr << 16) + self.fetch16() + idx_x) & 0xFFFFFF
        if mode == 'aby':
            return ((self.dbr << 16) + self.fetch16() + idx_y) & 0xFFFFFF
        if mode == 'long':
            return self.fetch24()
        if mode == 'lgx':
            return (self.fetch24() + idx_x) & 0xFFFFFF
        if mode == 'dp':
            return self.dpa(self.fetch())
        if mode == 'dpx':
            return self.dpa(self.fetch() + idx_x)
        if mode == 'dpy':
            return self.dpa(self.fetch() + idx_y)
        if mode == 'ind':
            return (self.dbr << 16) | self.dp_ptr16(self.fetch())
        if mode == 'inx':
            return (self.dbr << 16) | self.dp_ptr16(self.fetch() + idx_x)
        if mode == 'iny':
            return ((self.dbr << 16) + self.dp_ptr16(self.fetch()) + idx_y) & 0xFFFFFF
        if mode == 'inl':
            return self.dp_ptr24(self.fetch())
        if mode == 'ily':
            return (self.dp_ptr24(self.fetch()) + idx_y) & 0xFFFFFF
        if mode == 'sr':
            return (self.sp + self.fetch()) & 0xFFFF
        if mode == 'sry':
            ptr = self.rd16((self.sp + self.fetch()) & 0xFFFF)
            return ((self.dbr << 16) + ptr + idx_y) & 0xFFFFFF
        raise Unsupported(f"addressing mode {mode}")

    # ---- execution ----------------------------------------------------------------------------
    def step(self):
        pc0 = (self.pbr << 16) | self.pc
        code = self.fetch()
        name, mode = OPCODES[code]
        self.count += 1
        fn = getattr(self, "op_" + name, None)
        if fn is None:
            raise Unsupported(f"{name} (opcode {code:02X}) at {pc0:06X}")
        cyc = cycles_estimate(name, mode, self.m8, self.x8)
        moved0 = getattr(self, "moved", 0)
        fn(mode, pc0)
        if name in ("MVN", "MVP"):
            cyc = 7 * (getattr(self, "moved", 0) - moved0)
        elif mode == "rel" and name != "BRA" and ((self.pbr << 16) | self.pc) != pc0 + 2:
            cyc += 1                                    # a branch taken
        self.cycles += cyc
        return pc0

    def run(self, max_steps=1_000_000, halt_on_self_branch=True):
        """Run until an instruction that jumps to itself (BRA *), or max_steps. Returns the stop address."""
        for _ in range(max_steps):
            pc0 = self.step()
            if halt_on_self_branch and ((self.pbr << 16) | self.pc) == pc0:
                return pc0
        raise Unsupported(f"no halt within {max_steps} instructions (pc {self.pbr:02X}:{self.pc:04X})")

    # operand access for ALU-style instructions: returns (value, eight_bit, writeback address or None)
    def operand(self, mode, eight):
        if mode == 'imm':
            v = self.fetch()
            if not eight:
                v |= self.fetch() << 8
            return v, None
        a = self.ea(mode)
        return (self.rd(a) if eight else self.rd16(a)), a

    def store(self, a, v, eight):
        if eight:
            self.wr(a, v)
        else:
            self.wr16(a, v)

    # loads / stores
    def op_LDA(self, mode, pc):
        v, _ = self.operand(mode, self.m8)
        self.set_a(self.nz(v, self.m8))

    def op_LDX(self, mode, pc):
        v, _ = self.operand(mode, self.x8)
        self.set_x(self.nz(v, self.x8))

    def op_LDY(self, mode, pc):
        v, _ = self.operand(mode, self.x8)
        self.set_y(self.nz(v, self.x8))

    def op_STA(self, mode, pc): self.store(self.ea(mode), self.a, self.m8)
    def op_STX(self, mode, pc): self.store(self.ea(mode), self.x, self.x8)
    def op_STY(self, mode, pc): self.store(self.ea(mode), self.y, self.x8)
    def op_STZ(self, mode, pc): self.store(self.ea(mode), 0, self.m8)

    # logic and arithmetic
    def op_AND(self, mode, pc):
        v, _ = self.operand(mode, self.m8)
        self.set_a(self.nz(self.a & v, self.m8))

    def op_ORA(self, mode, pc):
        v, _ = self.operand(mode, self.m8)
        self.set_a(self.nz(self.a | v, self.m8))

    def op_EOR(self, mode, pc):
        v, _ = self.operand(mode, self.m8)
        self.set_a(self.nz(self.a ^ v, self.m8))

    def _addsub(self, v, sub):
        if self.p & D:
            raise Unsupported("decimal-mode arithmetic")
        eight = self.m8
        mask, sign = (0xFF, 0x80) if eight else (0xFFFF, 0x8000)
        a = self.a
        if sub:
            v = ~v & mask
        r = a + v + (self.p & C)
        self.flag(C, r > mask)
        self.flag(V, (~(a ^ v) & (a ^ r)) & sign)
        self.set_a(self.nz(r, eight))

    def op_ADC(self, mode, pc): self._addsub(self.operand(mode, self.m8)[0], False)
    def op_SBC(self, mode, pc): self._addsub(self.operand(mode, self.m8)[0], True)

    def _compare(self, reg, eight, mode):
        v, _ = self.operand(mode, eight)
        mask = 0xFF if eight else 0xFFFF
        self.flag(C, reg >= v)
        self.nz((reg - v) & mask, eight)

    def op_CMP(self, mode, pc): self._compare(self.a, self.m8, mode)
    def op_CPX(self, mode, pc): self._compare(self.x, self.x8, mode)
    def op_CPY(self, mode, pc): self._compare(self.y, self.x8, mode)

    def op_BIT(self, mode, pc):
        eight = self.m8
        v, _ = self.operand(mode, eight)
        self.flag(Z, (self.a & v) == 0)
        if mode != 'imm':
            self.flag(N, v & (0x80 if eight else 0x8000))
            self.flag(V, v & (0x40 if eight else 0x4000))

    def _rmw(self, mode, fn):
        eight = self.m8
        if mode == 'acc':
            self.set_a(fn(self.a, eight))
        else:
            a = self.ea(mode)
            v = self.rd(a) if eight else self.rd16(a)
            self.store(a, fn(v, eight), eight)

    def op_ASL(self, mode, pc):
        def f(v, e):
            self.flag(C, v & (0x80 if e else 0x8000))
            return self.nz(v << 1, e)
        self._rmw(mode, f)

    def op_LSR(self, mode, pc):
        def f(v, e):
            self.flag(C, v & 1)
            return self.nz(v >> 1, e)
        self._rmw(mode, f)

    def op_ROL(self, mode, pc):
        def f(v, e):
            c = self.p & C
            self.flag(C, v & (0x80 if e else 0x8000))
            return self.nz((v << 1) | c, e)
        self._rmw(mode, f)

    def op_ROR(self, mode, pc):
        def f(v, e):
            c = self.p & C
            self.flag(C, v & 1)
            return self.nz((v >> 1) | (c << (7 if e else 15)), e)
        self._rmw(mode, f)

    def op_INC(self, mode, pc): self._rmw(mode, lambda v, e: self.nz(v + 1, e))
    def op_DEC(self, mode, pc): self._rmw(mode, lambda v, e: self.nz(v - 1, e))

    def op_TSB(self, mode, pc):
        def f(v, e):
            self.flag(Z, (self.a & v) == 0)
            return v | self.a
        self._rmw(mode, f)

    def op_TRB(self, mode, pc):
        def f(v, e):
            self.flag(Z, (self.a & v) == 0)
            return v & ~self.a
        self._rmw(mode, f)

    # index register inc/dec and transfers
    def op_INX(self, mode, pc): self.set_x(self.nz(self.x + 1, self.x8))
    def op_INY(self, mode, pc): self.set_y(self.nz(self.y + 1, self.x8))
    def op_DEX(self, mode, pc): self.set_x(self.nz(self.x - 1, self.x8))
    def op_DEY(self, mode, pc): self.set_y(self.nz(self.y - 1, self.x8))

    def op_TAX(self, mode, pc): self.set_x(self.nz(self.c if not self.x8 else self.c & 0xFF, self.x8))
    def op_TAY(self, mode, pc): self.set_y(self.nz(self.c if not self.x8 else self.c & 0xFF, self.x8))

    def op_TXA(self, mode, pc): self.set_a(self.nz(self.x, self.m8))
    def op_TYA(self, mode, pc): self.set_a(self.nz(self.y, self.m8))
    def op_TXY(self, mode, pc): self.set_y(self.nz(self.x, self.x8))
    def op_TYX(self, mode, pc): self.set_x(self.nz(self.y, self.x8))

    def op_TXS(self, mode, pc): self.sp = (self.x & 0xFF) | 0x100 if self.e else self.x
    def op_TSX(self, mode, pc): self.set_x(self.nz(self.sp, self.x8))

    def op_TCD(self, mode, pc): self.dp = self.nz(self.c, False)
    def op_TDC(self, mode, pc): self.c = self.nz(self.dp, False)
    def op_TCS(self, mode, pc): self.sp = (self.c & 0xFF) | 0x100 if self.e else self.c
    def op_TSC(self, mode, pc): self.c = self.nz(self.sp, False)

    def op_XBA(self, mode, pc):
        self.c = ((self.c << 8) | (self.c >> 8)) & 0xFFFF
        self.nz(self.c & 0xFF, True)

    def op_XCE(self, mode, pc):
        carry = self.p & C
        self.flag(C, self.e)
        self.e = carry
        if self.e:
            self.p |= M | X
            self.x &= 0xFF
            self.y &= 0xFF
            self.sp = 0x100 | (self.sp & 0xFF)

    # flags
    def op_CLC(self, mode, pc): self.flag(C, 0)
    def op_SEC(self, mode, pc): self.flag(C, 1)
    def op_CLI(self, mode, pc): self.flag(I, 0)
    def op_SEI(self, mode, pc): self.flag(I, 1)
    def op_CLD(self, mode, pc): self.flag(D, 0)
    def op_SED(self, mode, pc): self.flag(D, 1)
    def op_CLV(self, mode, pc): self.flag(V, 0)
    def op_NOP(self, mode, pc): pass

    def op_REP(self, mode, pc): self.set_p(self.p & ~self.fetch())
    def op_SEP(self, mode, pc): self.set_p(self.p | self.fetch())

    # branches
    def _branch(self, mode, taken):
        off = self.fetch()
        if taken:
            self.pc = (self.pc + (off - 256 if off & 0x80 else off)) & 0xFFFF

    def op_BRA(self, mode, pc): self._branch(mode, True)
    def op_BEQ(self, mode, pc): self._branch(mode, self.p & Z)
    def op_BNE(self, mode, pc): self._branch(mode, not self.p & Z)
    def op_BCS(self, mode, pc): self._branch(mode, self.p & C)
    def op_BCC(self, mode, pc): self._branch(mode, not self.p & C)
    def op_BMI(self, mode, pc): self._branch(mode, self.p & N)
    def op_BPL(self, mode, pc): self._branch(mode, not self.p & N)
    def op_BVS(self, mode, pc): self._branch(mode, self.p & V)
    def op_BVC(self, mode, pc): self._branch(mode, not self.p & V)

    def op_BRL(self, mode, pc):
        off = self.fetch16()
        self.pc = (self.pc + (off - 65536 if off & 0x8000 else off)) & 0xFFFF

    # jumps and calls
    def op_JMP(self, mode, pc):
        if mode == 'abs':
            self.pc = self.fetch16()
        elif mode == 'long':
            a = self.fetch24()
            self.pc, self.pbr = a & 0xFFFF, a >> 16
        elif mode == 'abi':
            self.pc = self.rd16(self.fetch16())
        elif mode == 'aix':
            self.pc = self.rd16((self.pbr << 16) | ((self.fetch16() + self.x) & 0xFFFF))
        else:
            raise Unsupported(f"JMP {mode}")

    def op_JML(self, mode, pc):
        a = self.rd24(self.fetch16())
        self.pc, self.pbr = a & 0xFFFF, a >> 16

    def op_JSR(self, mode, pc):
        if mode == 'abs':
            t = self.fetch16()
        else:                                           # (abs,X)
            t = self.rd16((self.pbr << 16) | ((self.fetch16() + self.x) & 0xFFFF))
        self.push16((self.pc - 1) & 0xFFFF)             # the address of the last operand byte
        self.pc = t

    def op_JSL(self, mode, pc):
        a = self.fetch24()
        self.push(self.pbr)
        self.push16((self.pc - 1) & 0xFFFF)
        self.pc, self.pbr = a & 0xFFFF, a >> 16

    def op_RTS(self, mode, pc): self.pc = (self.pull16() + 1) & 0xFFFF

    def op_RTL(self, mode, pc):
        self.pc = (self.pull16() + 1) & 0xFFFF
        self.pbr = self.pull()

    def op_RTI(self, mode, pc):
        self.set_p(self.pull())
        self.pc = self.pull16()
        if not self.e:
            self.pbr = self.pull()

    # stack
    def op_PHA(self, mode, pc): self.push(self.a) if self.m8 else self.push16(self.a)
    def op_PHX(self, mode, pc): self.push(self.x) if self.x8 else self.push16(self.x)
    def op_PHY(self, mode, pc): self.push(self.y) if self.x8 else self.push16(self.y)
    def op_PHP(self, mode, pc): self.push(self.p | (0x30 if self.e else 0))
    def op_PHB(self, mode, pc): self.push(self.dbr)
    def op_PHK(self, mode, pc): self.push(self.pbr)
    def op_PHD(self, mode, pc): self.push16(self.dp)

    def op_PLA(self, mode, pc):
        self.set_a(self.nz(self.pull() if self.m8 else self.pull16(), self.m8))

    def op_PLX(self, mode, pc):
        self.set_x(self.nz(self.pull() if self.x8 else self.pull16(), self.x8))

    def op_PLY(self, mode, pc):
        self.set_y(self.nz(self.pull() if self.x8 else self.pull16(), self.x8))

    def op_PLP(self, mode, pc): self.set_p(self.pull())
    def op_PLB(self, mode, pc): self.dbr = self.nz(self.pull(), True)
    def op_PLD(self, mode, pc): self.dp = self.nz(self.pull16(), False)
    def op_PEA(self, mode, pc): self.push16(self.fetch16())

    def op_PEI(self, mode, pc): self.push16(self.dp_ptr16(self.fetch()))

    def op_PER(self, mode, pc):
        off = self.fetch16()
        self.push16((self.pc + (off - 65536 if off & 0x8000 else off)) & 0xFFFF)

    # block moves: operand bytes are destination bank, then source bank
    def _block(self, step):
        dst, src = self.fetch(), self.fetch()
        if self.e:
            raise Unsupported("block move in emulation mode")
        self.dbr = dst
        mask = 0xFF if self.x8 else 0xFFFF
        while True:
            self.wr((dst << 16) | self.y, self.rd((src << 16) | self.x))
            self.x = (self.x + step) & mask
            self.y = (self.y + step) & mask
            self.c = (self.c - 1) & 0xFFFF
            self.moved += 1
            if self.c == 0xFFFF:
                break

    def op_MVN(self, mode, pc): self._block(1)
    def op_MVP(self, mode, pc): self._block(-1)
