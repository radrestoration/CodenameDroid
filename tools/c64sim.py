"""The C64 build running headless in the plain Python 6502 interpreter (sim6502.py): the PRG is
loaded as the KERNAL would (no KERNAL here), run from `start`, and the one hardware wait (the
raster poll in hw_wait_frame) is trapped as "a frame passed". Everything else is ordinary RAM.

    from c64sim import C64
    c = C64(); c.run_frames(100)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sim6502 import CPU  # noqa: E402
import bbcmem as bm  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(HERE, "..", os.environ.get("C64_BUILD", os.path.join("build", "c64")))
CHARSET, MATRIX, CELLCHAR = 0xa000, 0xa800, 0xb000


def _ring_w():
    """The ring's row length in cells of the build being simulated (RING_W in its params.inc)."""
    for line in open(os.path.join(BUILD, "gen", "params.inc")):
        if line.startswith("RING_W"):
            return int(line.split("=")[1])
    return 32


RING_W = _ring_w()
RING_CELLS = RING_W * 32
RING = 0x8000 - RING_CELLS * 8           # the ring ends at $8000
CRTC_BASE = RING // 8 >> 8               # the CRTC start address's high byte for the ring's first cell ($0c, or $0b)


def load_labels(path=os.path.join(BUILD, "c64.lbl")):
    d = {}
    for line in open(path):
        _, a, n = line.split()
        d[n[1:]] = int(a, 16)
    return d


class C64:
    class WaitingForKey(Exception):
        pass

    rdch_keys = None
    stop_at_rdch = False

    def __init__(self, prg=os.path.join(BUILD, "droid.prg"), scan="trap"):
        """scan="trap": the keyboard scan routine is skipped and the keys the test holds are put
        straight into the OS variables (as the BBC harness does); scan="real" runs the real scan,
        reading a model of the keyboard matrix and joystick (see press / joystick)."""
        self.syms = load_labels()
        self.rdch_keys = []
        self.scan = scan
        cpu = self.cpu = CPU()
        data = open(prg, "rb").read()
        addr = data[0] | data[1] << 8
        cpu.m[addr:addr + len(data) - 2] = data[2:]
        if not os.environ.get("C64_INTRO"):
            cpu.m[0x278] = 0xa5         # INTRO_SKIP: no loading screens (they wait for the raster; tools/test_intro.py runs them)
        cpu.pc = self.syms["start"]
        cpu.sp = 0xff
        cpu.i = 1
        cpu.traps[self.syms["hw_wait_frame"]] = self._frame
        cpu.traps[self.syms["hw_after_frame"]] = self._after_present   # runs after the engine's present
        if scan == "trap":
            cpu.traps[self.syms["c64_scan_keys"]] = lambda c: None

            def rdch(c):                # as the BBC harness: the terminal's key read returns a space at once (or the keys
                if self.rdch_keys:      # given: rdch_keys; or stops: stop_at_rdch, to look at the screen that is up)
                    c.a = self.rdch_keys.pop(0)
                elif self.stop_at_rdch:
                    raise C64.WaitingForKey()
                else:
                    c.a = 0x20
                c.c = 0
            cpu.traps[self.syms["c64_osrdch"]] = rdch
        self.pressed = set()            # (column, row) of keyboard matrix keys down
        self.joy = 0x1f                 # joystick 2 lines, 0 = pressed
        # the memory under the I/O area and the character ROM, by the processor port ($01): 4 = all RAM; 1-3 = RAM and
        # the character ROM at $d000-$dfff (which is VICE's, when it is installed: only the pictures of the loading
        # screens need it); 5-7 = I/O
        self.ram_d = bytearray(0x1000)
        self.chargen = bytearray(0x1000)
        for chargen in ("/usr/lib/vice/C64/chargen-901225-01.bin", "/usr/share/vice/C64/chargen-901225-01.bin"):
            if os.path.exists(chargen):
                self.chargen[:] = open(chargen, "rb").read()[:0x1000]
                break
        raw_rd, raw_wr = cpu.rd, cpu.wr

        def rd(a, _r=raw_rd):
            if 0xd000 <= a < 0xe000:
                p = cpu.m[1] & 7
                if p == 4:
                    return self.ram_d[a - 0xd000]
                if p in (1, 2, 3):
                    return self.chargen[a - 0xd000]
            return _r(a)

        def wr(a, v, _w=raw_wr):
            if 0xd000 <= a < 0xe000 and cpu.m[1] & 7 in (1, 2, 3, 4):
                self.ram_d[a - 0xd000] = v & 0xff
                return
            _w(a, v)
        cpu.rd, cpu.wr = rd, wr
        cpu.write_hooks.append(self._cia)
        self.port_writes = []           # writes to $00/$01 (the 6510's port) by anything but start-up
        cpu.write_hooks.append(self._port_guard)
        self.frames = 0
        self.frame_cycles = []
        self._last = 0
        self.held = []                  # BBC key codes the game should see
        self.timer = 0
        self.on_frame = None            # fn(c64) called at each vertical blank, before the engine's present
        self.after_present = None       # fn(c64) called once the engine has updated the display
        self.min_sp = 0xff
        self.irq_every = 17095 if scan == "real" else 0     # the raster interrupt, in CPU cycles (NTSC frame)
        self._next_irq = self.irq_every

    @property
    def m(self):
        return self.cpu.m

    def _frame(self, cpu):
        self.frames += 1
        self.frame_cycles.append(cpu.cycles - self._last)
        self.timer = (self.timer + 37) & 0xff
        self.m[0xdc04] = self.timer     # the "random" timer: same sequence as the BBC harness
        if self.irq_every:                          # waiting for the frame takes the CPU to the next frame boundary
            cpu.cycles = max(cpu.cycles, self._next_irq)
        if self.scan == "trap":
            self.apply_keys()
        elif not self.irq_every:
            self.call("c64_scan_keys")
        if self.on_frame:
            self.on_frame(self)
        self._last = cpu.cycles         # (the engine's present runs after this, so is counted in the next frame)

    def _port_guard(self, addr, val):
        if addr < 2 and self.cpu.pc >= 0x1100 and not (0x8000 <= self.cpu.pc < 0x8180):   # start (at $8000) sets $01
            self.port_writes.append((addr, val, self.cpu.pc))

    def _cia(self, addr, val):
        """A tiny model of CIA 1: writing a column select to $dc00 puts that column's rows (0 = down)
        in $dc01; switching port A to inputs ($dc02 = 0) makes $dc00 read the joystick."""
        if addr == 0xdc00:
            rows = 0xff
            for col in range(8):
                if not val & (1 << col):
                    for (c, r) in self.pressed:
                        if c == col:
                            rows &= ~(1 << r)
            self.m[0xdc01] = rows
        elif addr == 0xdc02 and val == 0:
            self.m[0xdc00] = 0xe0 | self.joy

    def apply_keys(self):
        self.m[0xec] = self.held[-1] if self.held else 0
        self.m[0xed] = self.held[0] if self.held else 0

    def _after_present(self, cpu):
        if self.after_present:
            self.after_present(self)

    def call(self, label, max_steps=200000):
        """Run a routine (by label) as a subroutine call and return; registers and memory as it leaves them."""
        cpu = self.cpu
        save = (cpu.pc, cpu.sp)
        ret = 0xfff0
        cpu.push(((ret - 1) >> 8) & 255)
        cpu.push((ret - 1) & 255)
        cpu.pc = self.syms[label] if isinstance(label, str) else label
        n = 0
        while cpu.pc != ret and n < max_steps:
            cpu.step()
            n += 1
        assert cpu.pc == ret, "routine did not return"
        cpu.pc, cpu.sp = save

    def _step(self):
        cpu = self.cpu
        cpu.step()
        if cpu.sp < self.min_sp:
            self.min_sp = cpu.sp
        if self.irq_every and cpu.cycles >= self._next_irq:
            self._next_irq += self.irq_every
            if not cpu.i:                           # deliver the raster IRQ: push PC and P, vector via $fffe
                cpu.push(cpu.pc >> 8)
                cpu.push(cpu.pc & 255)
                cpu.push(cpu.p() & ~0x10)
                cpu.i = 1
                cpu.pc = cpu.rw(0xfffe)

    def run_frames(self, n):
        target = self.frames + n
        while self.frames < target:
            self._step()

    def run_cycles(self, n):
        """Run for n CPU cycles (for screens that wait without waiting for the frame)."""
        end = self.cpu.cycles + n
        while self.cpu.cycles < end:
            self._step()

    # ---- what the VIC-II would show ---------------------------------------------------------------
    def display_base(self):
        """The matrix the picture comes from: the one $d018 selects, or, when the back matrix is complete and the
        swap (the interrupt's) is still to come, that one - it is what the next frame shows."""
        m = self.m
        if m[0x20c]:
            return m[0x20b] << 8
        return 0x8000 + ((m[0xd018] >> 4) & 15) * 0x400

    def matrix_pixels(self):
        """25 rows x the view's columns of cells -> numpy (200, 4 * columns) array of pixel values 0-3."""
        import numpy as np
        m = self.m
        base = self.display_base()
        cols, col0 = m[0x215], m[0x214]
        out = np.zeros((200, 4 * cols), dtype=np.uint8)
        for r in range(25):
            for c in range(cols):
                ch = m[base + 40 * r + col0 + c]
                for line in range(8):
                    b = m[CHARSET + ch * 8 + line]
                    for p in range(4):
                        out[r * 8 + line, c * 4 + p] = (b >> (6 - 2 * p)) & 3
        return out

    def ring_cell_pixels(self, idx):
        import numpy as np
        m = self.m
        out = np.zeros((8, 4), dtype=np.uint8)
        for line in range(8):
            out[line] = bm.pixels(m[RING + idx * 8 + line])
        return out

    def view_base(self):
        """Ring cell index at the matrix's top left (S + RING_W * cam), as the engine computes it."""
        S = ((self.m[self.syms_zp("c64_crtc_high")] - CRTC_BASE) << 8) | self.m[self.syms_zp("c64_crtc_low")]
        return (S + RING_W * self.m[0x0203]) % RING_CELLS

    @staticmethod
    def syms_zp(name):
        return {"c64_crtc_high": 0x0200, "c64_crtc_low": 0x0201}[name]


# ---- rendering what the VIC-II would show (multicolour character mode) -----------------------------
C64_RGB = [(0, 0, 0), (255, 255, 255), (136, 57, 50), (103, 182, 189), (139, 63, 150), (85, 160, 73),
           (64, 49, 141), (191, 206, 114), (139, 84, 41), (87, 66, 0), (184, 105, 98), (80, 80, 80),
           (120, 120, 120), (148, 224, 137), (120, 105, 196), (159, 159, 159)]


def render_screen(c, scale=3):
    """PIL image of the 40x25 multicolour text screen as the VIC-II would draw it: the matrix, the
    charset, $d021-$d023 and the colour RAM (here a constant, set from the low 3 bits)."""
    import numpy as np
    from PIL import Image
    m = c.m
    base = c.display_base()
    bg = [m[0xd021] & 15, m[0xd022] & 15, m[0xd023] & 15]
    img = np.zeros((200, 160, 3), dtype=np.uint8)
    for r in range(25):
        for col in range(40):
            ch = m[base + 40 * r + col]
            fg = m[0xd800 + 40 * r + col] & 7
            mc = m[0xd800 + 40 * r + col] & 8
            for line in range(8):
                b = m[CHARSET + ch * 8 + line]
                for p in range(4):
                    v = (b >> (6 - 2 * p)) & 3
                    colour = bg[v] if v < 3 else fg
                    img[r * 8 + line, col * 4 + p] = C64_RGB[colour]
    if not m[0xd011] & 8:               # 24 rows: the window is 192 lines, 4 lines in from each end of the 25-row one;
        shifted = np.zeros_like(img)    # with YSCROLL 7 the matrix starts at its top, so rows 0-23 show
        if m[0xd011] & 7 == 7:
            shifted[4:196] = img[:192]
        else:
            shifted[4:196] = img[4:196]
        img = shifted
    im = Image.fromarray(img).resize((160 * 2 * scale, 200 * scale), Image.NEAREST)
    return im
