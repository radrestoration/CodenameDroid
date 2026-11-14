"""A model of an Apple IIgs for booting the disk images headlessly: the 65816 interpreter plus
  - a slot-5 SmartPort (what the Firmware Reference ch. 7 and the working hfs-boot loader say): signature bytes in the slot ROM,
    dispatch at $Cs00 + [$CsFF] + 3, standard ReadBlock only, asserting it is called in emulation mode with D = 0 and DBR = 0,
    returning carry clear, A = 0 to JSR + 3, serving blocks from the image;
  - the keyboard as GSplus models it: a queue of key events ($C000 shows the head, every read of $C010 moves the queue on),
    bit 7 of $C010 = a key is down, $C025 for the Open/Closed Apple keys;
  - a vertical-blank clock on $C019 (bit 7 = 0 during the blank), counted in instructions;
  - junk in the RAM banks so nothing can rely on zeroed memory.
Nothing here proves the real firmware behaves like the model; the grey-bar and loader runs in GSplus confirmed the block-0 entry
and the SmartPort calls."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from sim65816 import Sim65816

DISPATCH_OFFSET = 0x10
SLOT = 5
DISPATCH = 0xC000 + SLOT * 0x100 + DISPATCH_OFFSET + 3
JUNK = 0xA5
VBL_PERIOD, VBL_LENGTH = 30000, 4000        # instructions per frame, and how many of them are in the blank


class Machine(Sim65816):
    """The interpreter plus a slot-5 SmartPort, the keyboard strobe and the I/O window of the IIgs."""

    def __init__(self, image, fail_block=None, bad_signature=False):
        super().__init__()
        self.image = image
        self.fail_block = fail_block
        self.reads = []
        self.key_reads = 0
        self.kq = []                            # the keyboard's queue of key events (GSplus keeps 8)
        self.hold_total = 0                     # the key counts as held until this many scrolls have started
        self.scrolls_started = 0
        self.scroll_pcs = ()
        self.key_down = False                   # a key is physically down (set and cleared by the test)
        self.modifiers = 0
        for lo, hi in ((0x0000, 0x10000), (0x020000, 0x050000), (0xE10000, 0xE20000)):
            self.mem[lo:hi] = bytes([JUNK]) * (hi - lo)
        slot_rom = 0xC000 + SLOT * 0x100
        self.mem[slot_rom:slot_rom + 0x100] = bytes(0x100)
        for off, v in ((1, 0x20), (3, 0x00), (5, 0x03 if not bad_signature else 0x04), (7, 0x00), (0xFF, DISPATCH_OFFSET)):
            self.mem[slot_rom + off] = v
        self.mem[0x0800:0x0A00] = image[:512]
        self.e, self.p, self.dp, self.dbr, self.pbr, self.pc = 1, 0x34, 0, 0, 0, 0x0801
        self.sp = 0x01FF
        self.x = SLOT << 4
        self.io[(0xE0, 0xC034)] = 0x00

    def rd(self, a):
        a &= 0xFFFFFF
        if a == 0xE0C019:                       # vertical blank: bit 7 clear
            return 0x00 if self.count % VBL_PERIOD < VBL_LENGTH else 0x80
        if a == 0xE0C025:                       # the Apple keys: bit 7 Open Apple, bit 6 Closed Apple / Option
            return self.modifiers
        if a == 0xE0C000:                       # the newest-first view GSplus gives: the head of the key queue, strobe set
            return (self.kq[0] | 0x80) if self.kq else 0
        if a == 0xE0C010:                       # every read moves the queue on (GSplus adb_access_c010); bit 7 = a key is down
            self.key_reads += 1
            if self.kq:
                self.kq.pop(0)
            return 0x80 if (self.scrolls_started < self.hold_total or self.key_down) else 0
        return super().rd(a)

    def step(self):
        if (self.pbr << 16 | self.pc) in self.scroll_pcs:
            self.scrolls_started += 1
        if (self.pbr << 16 | self.pc) == DISPATCH:
            self.smartport()
            return DISPATCH
        return super().step()

    def smartport(self):
        assert (self.e, self.dp, self.dbr) == (1, 0, 0), \
            f"SmartPort must be called in emulation mode with D = 0 and DBR = 0 (e {self.e}, D {self.dp:04X}, DBR {self.dbr:02X})"
        ra = self.pull16()                      # JSR pushed the address of its last byte
        cmd, plist = self.rd(ra + 1), self.rd16(ra + 2)
        assert cmd == 1, f"only ReadBlock (1) is modelled, got {cmd}"
        pcount, unit, buf = self.rd(plist), self.rd(plist + 1), self.rd16(plist + 2)
        block = self.rd(plist + 4) | self.rd(plist + 5) << 8 | self.rd(plist + 6) << 16
        assert (pcount, unit) == (3, 1), (pcount, unit)
        assert buf >= 0x100 and buf + 512 <= 0xC000, f"buffer ${buf:04X}"
        self.reads.append(block)
        self.pc = (ra + 4) & 0xFFFF             # JSR + 3: past the command byte and the list pointer
        if block == self.fail_block:
            self.c, self.p = 0x27, self.p | 1   # I/O error, carry set
            return
        self.mem[buf:buf + 512] = self.image[block * 512:block * 512 + 512]
        self.c, self.p = 0, self.p & ~1         # A = 0, carry clear


def run_until(m, pc, limit=3_000_000, after=0):
    for _ in range(limit):
        if (m.pbr << 16 | m.pc) == pc and m.count > after:
            return
        m.step()
    raise AssertionError(f"did not reach ${pc:04X}")


def run_to_halt(m, limit=3_000_000):
    """Run until an instruction branches to itself."""
    for _ in range(limit):
        at = m.pbr << 16 | m.pc
        m.step()
        if (m.pbr << 16 | m.pc) == at:
            return at
    raise AssertionError("no halt")


def labels(path):
    return {l.split()[2].lstrip("."): int(l.split()[1], 16) for l in path.read_text().splitlines() if l.startswith("al ")}


