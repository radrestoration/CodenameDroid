"""The original BBC game running headless in a plain Python 6502 interpreter
(sim6502.py): the rebuilt CDroid4, started at its own entry point, with the few OS
calls it makes stubbed and the keyboard fed from a script. Used to measure what the
original costs per frame, to watch real behaviour (enemy movement, scrolling), and as
the reference for the C64 port. No emulator, no display.

    from bbcsim import BBC
    b = BBC(); b.run_frames(100); print(b.sym('player_x'))
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sim6502 import CPU  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(HERE, "..", "build", "bbc")

KEYS = {"Z": 0xe1, "X": 0xc2, ":": 0xc8, "/": 0xe8, "RETURN": 0xc9, "]": 0xd8,
        "SPACE": 0xe2, "J": 0xc5, "A": 0xc1, "COPY": 0xe9, "DELETE": 0xd9, "D": 0xb2, "TAB": 0xe0,
        "O": 0xb6, "ESCAPE": 0xf0}          # the OS's key codes as the game tests them


def load_symbols(path=os.path.join(BUILD, "disc.lbl")):
    syms = {}
    for line in open(path):
        _, addr, name = line.split()
        syms[name[1:]] = int(addr, 16)
    return syms


class BBC:
    OSWRCH, OSWORD, OSBYTE, OSCLI, OSRDCH = 0xffee, 0xfff1, 0xfff4, 0xfff7, 0xffe0

    def __init__(self):
        self.syms = load_symbols()
        cpu = self.cpu = CPU()
        f = open(os.path.join(BUILD, "CDroid4"), "rb").read()
        cpu.m[0x1100:0x1100 + len(f)] = f
        cpu.pc = 0x6e00
        cpu.sp = 0xff
        cpu.traps[self.OSWRCH] = self._oswrch
        cpu.traps[self.OSBYTE] = self._osbyte
        cpu.traps[self.OSWORD] = lambda c: None
        cpu.traps[self.OSCLI] = lambda c: None
        cpu.traps[self.OSRDCH] = self._osrdch
        cpu.write_hooks.append(self._write)
        self.frames = 0                 # OSBYTE 19 calls so far
        self.frame_cycles = []          # CPU cycles used between successive OSBYTE 19 calls
        self._last = 0
        self.keys = [0, 0]              # [&ec most recently pressed, &ed first pressed]
        self.crtc = [0] * 32
        self._crtc_reg = 0
        self.palette = {}
        self.vdu_pending = 0
        self.trace = None               # optional fn(bbc) called at each frame
        self.rdch_keys = []
        self.stop_at_rdch = False
        self._held = []
        self._apply_keys()

    # ---- OS ----------------------------------------------------------------
    def _oswrch(self, c):
        pass

    class WaitingForKey(Exception):
        pass

    def _osrdch(self, c):
        if self.rdch_keys:
            c.a = self.rdch_keys.pop(0)
        elif self.stop_at_rdch:
            raise BBC.WaitingForKey()       # the screen is up and the game waits: stop here to look at it
        else:
            c.a = 0x20
        c.c = 0

    def _osbyte(self, c):
        a = c.a
        if a == 0x13:                                    # wait for vertical retrace
            self.frames += 1
            self.frame_cycles.append(c.cycles - self._last)
            self._last = c.cycles
            self.m[0xfe64] = (self.m[0xfe64] + 37) & 0xff   # a changing value for the "random" timer read
            self._apply_keys()
            if self.trace:
                self.trace(self)
        elif a == 0x9b:
            self.palette[c.x >> 4] = c.x & 15
        elif a == 0x80:                                  # read buffer status: plenty of space
            c.x = 0xff
            c.y = 0
        # everything else (flush, auto-repeat, break effect, tape FS, ...) has no effect here

    @property
    def m(self):
        return self.cpu.m

    def _write(self, addr, val):
        if addr == 0xfe00:
            self._crtc_reg = val & 31
        elif addr == 0xfe01:
            self.crtc[self._crtc_reg] = val

    # ---- helpers -----------------------------------------------------------
    def sym(self, name):
        """Value of the byte at a labelled address (zero-page variables are equates in
        symbols.inc, not labels, so those are looked up by ZP name below)."""
        return self.m[self.syms[name]]

    def set_keys(self, *names):
        """Hold these keys (none = release everything) until the next call."""
        self._held = [KEYS[n] for n in names]
        self._apply_keys()

    def _apply_keys(self):
        held = self._held
        self.m[0xec] = held[-1] if held else 0
        self.m[0xed] = held[0] if held else 0

    def run_frames(self, n, held=None):
        """Run until n more vertical-retrace waits have happened."""
        if held is not None:
            self.set_keys(*held)
        target = self.frames + n
        cpu = self.cpu
        while self.frames < target:
            cpu.step()

    def run_until_pc(self, pc, limit=50_000_000):
        cpu = self.cpu
        n = 0
        while cpu.pc != pc and n < limit:
            cpu.step()
            n += 1
        return cpu.pc == pc

    # ---- the display -------------------------------------------------------
    def screen_start(self):
        """Address of the top-left of the display: CRTC R12/R13 (x8, wrapped into
        &6000-&7fff the way the CRTC's wrap-around does)."""
        return ((self.crtc[12] << 8 | self.crtc[13]) << 3) & 0xffff
