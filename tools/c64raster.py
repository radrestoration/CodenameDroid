"""The C64 build with the real raster-wait code running (c64sim.py traps it): $d011/$d012 follow the CPU
cycle count like the VIC-II's (PAL 312 lines of 63 cycles, NTSC 263 of 65), and the raster interrupt
(line $fb) is delivered at that line each frame.  A frame is one raster interrupt.

    from c64raster import C64Raster
    c = C64Raster(pal=True); c.run_frames(300)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from c64sim import C64  # noqa: E402


class C64Raster(C64):
    def __init__(self, pal=True, **kw):
        super().__init__(scan="real", **kw)
        self.cpu.traps.pop(self.syms["hw_wait_frame"])
        self.cyc_line, self.lines = (63, 312) if pal else (65, 263)
        self.frame_len = self.cyc_line * self.lines
        self.irq_every = 0                      # (the base class's timer is not used)
        self.irq_line = 0xfb
        self.irq_count = 0
        self._fire = self.irq_line * self.cyc_line
        cpu = self.cpu
        raw_rd = cpu.rd
        cyc_line, lines = self.cyc_line, self.lines

        def rd(a):
            a &= 0xffff
            if a == 0xd012 and cpu.m[1] & 7 >= 5:       # (the registers, when the I/O area is there)
                return ((cpu.cycles // cyc_line) % lines) & 0xff
            if a == 0xd011 and cpu.m[1] & 7 >= 5:
                return (cpu.m[0xd011] & 0x7f) | ((((cpu.cycles // cyc_line) % lines) >> 8) << 7)
            return raw_rd(a)
        cpu.rd = rd

    def _step(self):
        cpu = self.cpu
        cpu.step()
        if cpu.sp < self.min_sp:
            self.min_sp = cpu.sp
        if cpu.cycles >= self._fire:
            self._fire += self.frame_len
            self.frames += 1
            self.timer = (self.timer + 37) & 0xff
            self.m[0xdc04] = self.timer
            if not cpu.i and self.m[0xd01a] & 1:
                cpu.push(cpu.pc >> 8)
                cpu.push(cpu.pc & 255)
                cpu.push(cpu.p() & ~0x10)
                cpu.i = 1
                cpu.pc = cpu.rw(0xfffe)
