"""Minimal headless NMOS 6502 interpreter (documented opcodes only) with
approximate cycle counts - for unit-testing the C64 build without any
emulator or display."""

MODES = {}
def op(code, name, mode, cyc):
    MODES[code] = (name, mode, cyc)

_tbl = """
ADC 69 imm 2,65 zp 3,75 zpx 4,6D abs 4,7D abx 4,79 aby 4,61 izx 6,71 izy 5
AND 29 imm 2,25 zp 3,35 zpx 4,2D abs 4,3D abx 4,39 aby 4,21 izx 6,31 izy 5
ASL 0A acc 2,06 zp 5,16 zpx 6,0E abs 6,1E abx 7
BCC 90 rel 2
BCS B0 rel 2
BEQ F0 rel 2
BIT 24 zp 3,2C abs 4
BMI 30 rel 2
BNE D0 rel 2
BPL 10 rel 2
BRK 00 imp 7
BVC 50 rel 2
BVS 70 rel 2
CLC 18 imp 2
CLD D8 imp 2
CLI 58 imp 2
CLV B8 imp 2
CMP C9 imm 2,C5 zp 3,D5 zpx 4,CD abs 4,DD abx 4,D9 aby 4,C1 izx 6,D1 izy 5
CPX E0 imm 2,E4 zp 3,EC abs 4
CPY C0 imm 2,C4 zp 3,CC abs 4
DEC C6 zp 5,D6 zpx 6,CE abs 6,DE abx 7
DEX CA imp 2
DEY 88 imp 2
EOR 49 imm 2,45 zp 3,55 zpx 4,4D abs 4,5D abx 4,59 aby 4,41 izx 6,51 izy 5
INC E6 zp 5,F6 zpx 6,EE abs 6,FE abx 7
INX E8 imp 2
INY C8 imp 2
JMP 4C abs 3,6C ind 5
JSR 20 abs 6
LDA A9 imm 2,A5 zp 3,B5 zpx 4,AD abs 4,BD abx 4,B9 aby 4,A1 izx 6,B1 izy 5
LDX A2 imm 2,A6 zp 3,B6 zpy 4,AE abs 4,BE aby 4
LDY A0 imm 2,A4 zp 3,B4 zpx 4,AC abs 4,BC abx 4
LSR 4A acc 2,46 zp 5,56 zpx 6,4E abs 6,5E abx 7
NOP EA imp 2
ORA 09 imm 2,05 zp 3,15 zpx 4,0D abs 4,1D abx 4,19 aby 4,01 izx 6,11 izy 5
PHA 48 imp 3
PHP 08 imp 3
PLA 68 imp 4
PLP 28 imp 4
ROL 2A acc 2,26 zp 5,36 zpx 6,2E abs 6,3E abx 7
ROR 6A acc 2,66 zp 5,76 zpx 6,6E abs 6,7E abx 7
RTI 40 imp 6
RTS 60 imp 6
SBC E9 imm 2,E5 zp 3,F5 zpx 4,ED abs 4,FD abx 4,F9 aby 4,E1 izx 6,F1 izy 5
SEC 38 imp 2
SED F8 imp 2
SEI 78 imp 2
STA 85 zp 3,95 zpx 4,8D abs 4,9D abx 5,99 aby 5,81 izx 6,91 izy 6
STX 86 zp 3,96 zpy 4,8E abs 4
STY 84 zp 3,94 zpx 4,8C abs 4
TAX AA imp 2
TAY A8 imp 2
TSX BA imp 2
TXA 8A imp 2
TXS 9A imp 2
TYA 98 imp 2
"""
for line in _tbl.strip().splitlines():
    name, rest = line.split(" ", 1)
    for item in rest.split(","):
        code, mode, cyc = item.split()
        op(int(code, 16), name, mode, int(cyc))


class CPU:
    def __init__(self):
        self.m = bytearray(65536)
        self.a = self.x = self.y = 0
        self.sp = 0xFF
        self.pc = 0
        self.c = self.z = self.i = self.d = self.v = self.n = 0
        self.cycles = 0
        self.traps = {}           # addr -> fn(cpu); acts as subroutine (auto RTS)
        self.write_hooks = []     # fn(addr, val)

    def rd(self, a): return self.m[a & 0xFFFF]
    def wr(self, a, v):
        a &= 0xFFFF
        self.m[a] = v & 0xFF
        for h in self.write_hooks:
            h(a, v & 0xFF)
    def rw(self, a): return self.rd(a) | (self.rd(a + 1) << 8)
    def push(self, v): self.m[0x100 + self.sp] = v & 0xFF; self.sp = (self.sp - 1) & 0xFF
    def pull(self): self.sp = (self.sp + 1) & 0xFF; return self.m[0x100 + self.sp]
    def p(self):
        return (self.n << 7) | (self.v << 6) | 0x30 | (self.d << 3) | (self.i << 2) | (self.z << 1) | self.c
    def setp(self, v):
        self.n, self.v, self.d, self.i, self.z, self.c = (v >> 7) & 1, (v >> 6) & 1, (v >> 3) & 1, (v >> 2) & 1, (v >> 1) & 1, v & 1
    def nz(self, v):
        v &= 0xFF; self.n = v >> 7; self.z = int(v == 0); return v
    def rts(self):
        lo = self.pull(); hi = self.pull(); self.pc = ((hi << 8) | lo) + 1

    def addr(self, mode):
        pc = self.pc
        if mode == "imm": self.pc += 1; return pc
        if mode == "zp": self.pc += 1; return self.rd(pc)
        if mode == "zpx": self.pc += 1; return (self.rd(pc) + self.x) & 0xFF
        if mode == "zpy": self.pc += 1; return (self.rd(pc) + self.y) & 0xFF
        if mode == "abs": self.pc += 2; return self.rw(pc)
        if mode == "abx":
            self.pc += 2; b = self.rw(pc); r = (b + self.x) & 0xFFFF
            if (b ^ r) & 0xFF00: self.extra = 1
            return r
        if mode == "aby":
            self.pc += 2; b = self.rw(pc); r = (b + self.y) & 0xFFFF
            if (b ^ r) & 0xFF00: self.extra = 1
            return r
        if mode == "izx":
            self.pc += 1; z = (self.rd(pc) + self.x) & 0xFF
            return self.rd(z) | (self.rd((z + 1) & 0xFF) << 8)
        if mode == "izy":
            self.pc += 1; z = self.rd(pc); b = self.rd(z) | (self.rd((z + 1) & 0xFF) << 8)
            r = (b + self.y) & 0xFFFF
            if (b ^ r) & 0xFF00: self.extra = 1
            return r
        if mode == "ind":
            self.pc += 2; p = self.rw(pc)
            return self.rd(p) | (self.rd((p & 0xFF00) | ((p + 1) & 0xFF)) << 8)
        if mode == "rel": self.pc += 1; o = self.rd(pc); return (self.pc + (o - 256 if o > 127 else o)) & 0xFFFF
        raise ValueError(mode)

    def step(self):
        if self.pc in self.traps:
            self.traps[self.pc](self)
            self.rts()
            self.cycles += 6
            return
        code = self.rd(self.pc)
        if code not in MODES:
            raise RuntimeError(f"illegal opcode ${code:02X} at ${self.pc:04X}")
        name, mode, cyc = MODES[code]
        self.pc += 1
        self.extra = 0
        a = None
        if mode not in ("imp", "acc"):
            a = self.addr(mode)
        if name in ("LDA", "LDX", "LDY", "EOR", "AND", "ORA", "ADC", "SBC", "CMP") and self.extra:
            cyc += 1
        self.cycles += cyc
        getattr(self, "op_" + name)(a, mode)

    # loads/stores
    def op_LDA(self, a, m): self.a = self.nz(self.rd(a))
    def op_LDX(self, a, m): self.x = self.nz(self.rd(a))
    def op_LDY(self, a, m): self.y = self.nz(self.rd(a))
    def op_STA(self, a, m): self.wr(a, self.a)
    def op_STX(self, a, m): self.wr(a, self.x)
    def op_STY(self, a, m): self.wr(a, self.y)
    def op_TAX(self, a, m): self.x = self.nz(self.a)
    def op_TAY(self, a, m): self.y = self.nz(self.a)
    def op_TXA(self, a, m): self.a = self.nz(self.x)
    def op_TYA(self, a, m): self.a = self.nz(self.y)
    def op_TSX(self, a, m): self.x = self.nz(self.sp)
    def op_TXS(self, a, m): self.sp = self.x
    def op_PHA(self, a, m): self.push(self.a)
    def op_PHP(self, a, m): self.push(self.p())
    def op_PLA(self, a, m): self.a = self.nz(self.pull())
    def op_PLP(self, a, m): self.setp(self.pull())
    # logic/arith
    def op_AND(self, a, m): self.a = self.nz(self.a & self.rd(a))
    def op_ORA(self, a, m): self.a = self.nz(self.a | self.rd(a))
    def op_EOR(self, a, m): self.a = self.nz(self.a ^ self.rd(a))
    def op_BIT(self, a, m):
        v = self.rd(a); self.z = int((self.a & v) == 0); self.n = v >> 7; self.v = (v >> 6) & 1
    # Decimal mode (SED - e.g. chargen.s HEX2BCD): the result and carry
    # an NMOS 6502 gives for valid BCD operands; N/V/Z follow the binary
    # sum, as on the NMOS part (only defined for binary on it anyway).
    def op_ADC(self, a, m):
        v = self.rd(a); r = self.a + v + self.c
        self.v = int(((self.a ^ r) & (v ^ r) & 0x80) != 0)
        if self.d:
            lo = (self.a & 0x0F) + (v & 0x0F) + self.c
            if lo > 9:
                lo += 6
            hi = (self.a >> 4) + (v >> 4) + (lo > 0x0F)
            if hi > 9:
                hi += 6
            self.nz(r)
            self.c = int(hi > 15)
            self.a = ((hi << 4) | (lo & 0x0F)) & 0xFF
            return
        self.c = int(r > 255); self.a = self.nz(r)
    def op_SBC(self, a, m):
        v8 = self.rd(a); v = v8 ^ 0xFF; r = self.a + v + self.c
        self.v = int(((self.a ^ r) & (v ^ r) & 0x80) != 0)
        if self.d:
            lo = (self.a & 0x0F) - (v8 & 0x0F) - (1 - self.c)
            hi = (self.a >> 4) - (v8 >> 4)
            if lo < 0:
                lo -= 6
                hi -= 1
            if hi < 0:
                hi -= 6
            self.c = int(r > 255); self.nz(r)
            self.a = ((hi << 4) | (lo & 0x0F)) & 0xFF
            return
        self.c = int(r > 255); self.a = self.nz(r)
    def _cmp(self, reg, a): v = self.rd(a); self.c = int(reg >= v); self.nz(reg - v)
    def op_CMP(self, a, m): self._cmp(self.a, a)
    def op_CPX(self, a, m): self._cmp(self.x, a)
    def op_CPY(self, a, m): self._cmp(self.y, a)
    def op_INC(self, a, m): self.wr(a, self.nz(self.rd(a) + 1))
    def op_DEC(self, a, m): self.wr(a, self.nz(self.rd(a) - 1))
    def op_INX(self, a, m): self.x = self.nz(self.x + 1)
    def op_INY(self, a, m): self.y = self.nz(self.y + 1)
    def op_DEX(self, a, m): self.x = self.nz(self.x - 1)
    def op_DEY(self, a, m): self.y = self.nz(self.y - 1)
    def _sh(self, a, m, f):
        v = self.a if m == "acc" else self.rd(a)
        r = f(v)
        if m == "acc": self.a = self.nz(r)
        else: self.wr(a, self.nz(r))
    def op_ASL(self, a, m):
        def f(v): self.c = v >> 7; return (v << 1) & 0xFF
        self._sh(a, m, f)
    def op_LSR(self, a, m):
        def f(v): self.c = v & 1; return v >> 1
        self._sh(a, m, f)
    def op_ROL(self, a, m):
        def f(v): r = ((v << 1) | self.c) & 0xFF; self.c = v >> 7; return r
        self._sh(a, m, f)
    def op_ROR(self, a, m):
        def f(v): r = (v >> 1) | (self.c << 7); self.c = v & 1; return r
        self._sh(a, m, f)
    # flow
    def _br(self, a, cond):
        if cond:
            self.cycles += 1 + (1 if (a ^ self.pc) & 0xFF00 else 0)
            self.pc = a
    def op_BCC(self, a, m): self._br(a, not self.c)
    def op_BCS(self, a, m): self._br(a, self.c)
    def op_BEQ(self, a, m): self._br(a, self.z)
    def op_BNE(self, a, m): self._br(a, not self.z)
    def op_BMI(self, a, m): self._br(a, self.n)
    def op_BPL(self, a, m): self._br(a, not self.n)
    def op_BVC(self, a, m): self._br(a, not self.v)
    def op_BVS(self, a, m): self._br(a, self.v)
    def op_JMP(self, a, m): self.pc = a
    def op_JSR(self, a, m):
        r = self.pc - 1; self.push(r >> 8); self.push(r); self.pc = a
    def op_RTS(self, a, m): self.rts()
    def op_RTI(self, a, m): self.setp(self.pull()); lo = self.pull(); hi = self.pull(); self.pc = (hi << 8) | lo
    def op_BRK(self, a, m): raise RuntimeError(f"BRK at ${self.pc - 1:04X}")
    def op_CLC(self, a, m): self.c = 0
    def op_SEC(self, a, m): self.c = 1
    def op_CLI(self, a, m): self.i = 0
    def op_SEI(self, a, m): self.i = 1
    def op_CLD(self, a, m): self.d = 0
    def op_SED(self, a, m): self.d = 1
    def op_CLV(self, a, m): self.v = 0
    def op_NOP(self, a, m): pass


def install_sideways_banks(cpu, bank_images):
    """BBC sideways RAM simulation: on every write to ROMSEL ($FE30),
    swap the $8000-$BFFF window to the image for that raw bank number
    - cpu.m is one flat 64K array otherwise, so without this, a test
    that follows a real cross-bank call chain (e.g. LOADROOM, bank W,
    calling LOADFILE, bank Z) would read whichever bank happened to be
    loaded there LAST, not the one ROMSEL actually selects, silently
    passing or failing for the wrong reason.

    The outgoing bank's current window is saved back into bank_images
    before the new one is loaded, so writes made while a bank was
    selected (e.g. a boot sequence's own OSFILE loads into sideways
    RAM, each done with a different bank paged in) survive a later
    switch away and back - real sideways RAM behaves the same way.
    bank_images' values are converted to bytearrays here so they can
    be mutated in place.

    bank_images: {raw_romsel_value: bytes} - each image is placed at
    $8000, zero-padded to the full 16384-byte window. Call once per
    CPU, before running anything that pages between banks; the bank
    present at $8000 when this is called becomes the initial window.
    """
    for key, image in bank_images.items():
        bank_images[key] = bytearray(image) + bytearray(0x4000 - len(image))
    current = {"bank": None}

    def on_write(addr, value):
        if addr != 0xFE30:
            return
        prev = current["bank"]
        if prev is not None and prev in bank_images:
            bank_images[prev][:] = cpu.m[0x8000:0xC000]
        window = bank_images.get(value, bytearray(0x4000))
        cpu.m[0x8000:0xC000] = window
        current["bank"] = value
    cpu.write_hooks.append(on_write)
