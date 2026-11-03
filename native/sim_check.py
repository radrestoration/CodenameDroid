#!/usr/bin/env python3
"""A quick headless run of the engine prototype (build/proto/proto.prg): the 6502 with a model of the raster, the keyboard
and the interrupt. Runs frames with keys held, prints where the actors are and how long the work took, and renders the screen
(characters, fine scroll, sprites) to a PNG.   sim_check.py [pal|ntsc] [frames] [keys: Z X R] [out.png]"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "tools"))
from sim6502 import CPU  # noqa: E402

RGB = [(0, 0, 0), (255, 255, 255), (136, 0, 0), (170, 255, 238), (204, 68, 204), (0, 204, 85), (0, 0, 170), (238, 238, 119),
       (221, 136, 85), (102, 68, 0), (255, 119, 119), (51, 51, 51), (119, 119, 119), (170, 255, 102), (0, 136, 255), (187, 187, 187)]


KEYS = {"X": (0xfb, 0x80), "Z": (0xfd, 0x10), "UP": (0xbf, 0x04), "DOWN": (0xbf, 0x80), "A": (0xfd, 0x04), "J": (0xef, 0x04),
        "RET": (0xfe, 0x02), "FIRE": (0xbf, 0x20), "STOP": (0x7f, 0x80), "D": (0xfb, 0x04), "O": (0xef, 0x40), "SPACE": (0x7f, 0x10)}


NDIR = os.path.join(HERE, "..", os.environ.get("NATIVE", "build/native"))


def labels(path):
    out = {}
    for line in open(path):
        p = line.split()
        if len(p) == 3 and p[0] == "al":
            out[p[2].lstrip(".")] = int(p[1], 16)
    return out


class Machine:
    def __init__(self, pal=True):
        self.cpu = c = CPU()
        data = open(os.path.join(NDIR, "game.prg"), "rb").read()
        addr = data[0] | data[1] << 8
        c.m[addr:addr + len(data) - 2] = data[2:]
        c.pc, c.sp, c.i = 0x0810, 0xff, 1
        self.lines, self.per = (312, 63) if pal else (263, 65)
        self.frame = self.lines * self.per
        self.col = 0xff
        self.pressed = set()
        self.fired = False
        self.regs = {}
        self.border = []                                     # (cycle in frame, colour) writes of $d020
        c.rd = self.rd
        c.write_hooks.append(self.wr)
        self.base = 0
        self.shadow = bytearray(4096)
        self.io = bytearray(4096)
        self.irq_line = 20

    def raster(self):
        return (self.cpu.cycles % self.frame) // self.per

    def rd(self, a):
        a &= 0xffff
        m = self.cpu.m
        if 0xd000 <= a < 0xe000 and (m[1] & 7) in (0, 4):
            return self.shadow[a - 0xd000]
        if a == 0xd012:
            return self.raster() & 255
        if a == 0xd011:
            return (m[0xd011] & 0x7f) | ((self.raster() >> 8) << 7)
        if a == 0xdc00:
            v = 0xff
            if "L" in self.pressed:
                v &= ~4
            if "R2" in self.pressed:
                v &= ~8
            return v & 0xff
        if a == 0xdc01:
            v = 0xff
            for key, (colbyte, mask) in KEYS.items():
                if key in self.pressed:
                    c = [i for i in range(8) if not (colbyte >> i) & 1][0]
                    if not (self.col >> c) & 1:
                        v &= ~mask
            return v & 0xff
        return m[a]

    def wr(self, a, v):
        if 0xd000 <= a < 0xe000:
            i = a - 0xd000
            if (self.cpu.m[1] & 7) in (0, 4):             # RAM under the I/O area: the VIC-II sees it, the registers do not
                self.shadow[i] = v
                self.cpu.m[a] = self.io[i]
                return
            self.io[i] = v
        if a == 0xdc00:
            self.col = v
        if a == 0xd020:
            self.border.append((self.cpu.cycles % self.frame, v))

    def run_frame(self):
        c = self.cpu
        start = c.cycles - c.cycles % self.frame
        end = start + self.frame
        fire_at = start + self.irq_line * self.per
        done = False
        while c.cycles < end:
            if not done and c.cycles >= fire_at and c.m[0xd01a] & 1 and not c.i:
                c.push(c.pc >> 8)
                c.push(c.pc & 255)
                c.push(c.p() & ~0x10)
                c.i = 1
                c.pc = c.rw(0xfffe)
                c.cycles += 7
                done = True
            c.step()
        if not done:
            pass

    def render(self, path, scale=2):
        import numpy as np
        from PIL import Image
        m = self.cpu.m
        mat = 0xc000 + ((m[0xd018] >> 4) & 15) * 0x400
        chars = 0xc000 + ((m[0xd018] >> 1) & 7) * 0x800
        xs = m[0xd016] & 7
        bg = [m[0xd021] & 15, m[0xd022] & 15, m[0xd023] & 15]
        img = np.zeros((200, 320 + 8, 3), dtype=np.uint8)
        for r in range(25):
            for col in range(40):
                ch = m[mat + 40 * r + col]
                for line in range(8):
                    ad = chars + ch * 8 + line
                    b = self.shadow[ad - 0xd000] if 0xd000 <= ad < 0xe000 else m[ad]
                    for p in range(4):
                        v = (b >> (6 - 2 * p)) & 3
                        colour = bg[v] if v < 3 else (m[0xd800 + 40 * r + col] & 7)
                        x = col * 8 + p * 2 + xs
                        img[r * 8 + line, x:x + 2] = RGB[colour]
        en = m[0xd015]
        msb = m[0xd010]
        for s in range(8):
            if not (en >> s) & 1:
                continue
            sx = m[0xd000 + 2 * s] | (((msb >> s) & 1) << 8)
            sy = m[0xd001 + 2 * s]
            ptr = m[mat + 0x3f8 + s]
            base = 0xc000 + ptr * 64
            for line in range(21):
                for byte in range(3):
                    ad = base + line * 3 + byte
                    b = self.shadow[ad - 0xd000] if 0xd000 <= ad < 0xe000 else m[ad]
                    for p in range(4):
                        v = (b >> (6 - 2 * p)) & 3
                        if v == 0:
                            continue
                        colour = {1: m[0xd025], 2: m[0xd027 + s], 3: m[0xd026]}[v] & 15
                        y = sy - 50 + line
                        x = sx - 24 + byte * 8 + p * 2
                        if 0 <= y < 200 and 0 <= x < 328:
                            img[y, x:x + 2] = RGB[colour]
        im = Image.fromarray(img[:, :320])
        im.resize((320 * scale, 200 * scale), Image.NEAREST).save(path)


def main():
    args = sys.argv[1:]
    pal = not (args and args[0] == "ntsc")
    if args and args[0] in ("pal", "ntsc"):
        args = args[1:]
    frames = int(args[0]) if args else 100
    keys = set(args[1].split(",")) if len(args) > 1 and args[1] != "-" else set()
    out = args[2] if len(args) > 2 else os.path.join(HERE, "..", "build", "native", "check.png")
    mc = Machine(pal)
    lb = labels(os.path.join(HERE, "..", "build", "native", "game.lbl"))
    m = mc.cpu.m
    stats = []
    for f in range(frames):
        mc.pressed = keys if f >= 60 else set()
        mc.border.clear()
        mc.run_frame()
        ev = mc.border
        if len(ev) >= 4:
            first = ev[0][0]
            last = max(t for t, v in ev if v == 0) if any(v == 0 for t, v in ev) else ev[-1][0]
            red = 0
            for (t1, v1), (t2, v2) in zip(ev, ev[1:]):
                if v1 == 2:
                    red += t2 - t1
            stats.append((last - first, red))
    g = lambda n, i=0: m[lb[n] + i]
    if stats:
        work = [w for w, r in stats]
        print("cycles of work a frame: average %d, most %d (a frame is %d)" % (sum(work) / len(work), max(work), mc.frame))
    print("frames", frames, "tick", g("tick"), "pal", g("c64_pal"), "level", g("level"))
    print("player px", g("px"), "pc", g("pc"), "py", g("py"), "dir", g("pdir"), "stance", g("pstance"), "frame", g("pframe"),
          "jt", g("jump_timer"), "jf", g("pjf"), "energy", g("suit_energy"), "overflow", g("overflow"), "nchars", g("nchars"))
    print("window", g("cur_w"), "camera", g("cur_cam"), "xscroll", m[0xd016] & 7, "matrix", hex(m[0xd018]))
    mc.render(out)
    print("wrote", out)


if __name__ == "__main__":
    main()
