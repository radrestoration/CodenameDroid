"""The Super Hi-Res picture the C64 logic's memory describes, built independently of the display layer (hal/apple/gs/shr.s):
the shown matrix of characters (each character's 8 BBC bytes, BPAT, converted to Super Hi-Res bytes), then the logic's sprites
over it. `mem` is any indexable byte store, `base` the address of the logic's C64 address 0 in it (0 for bank 0, 0x020000 for
bank 2), `sym` the logic's equates (BPAT, MAT_A, MAT_B, SPRAREA), `lb` its labels.

The sprites follow the C64's semantics (tools/sim_check.py draws them the same way): sprite k is enabled by bit k of p_en, its
x is p_sx plus bit 8 from p_msb, its position on the 320 x 200 picture is (x - 24, y - 50) in C64 pixels, its image is 21 lines of
3 bytes at SPRAREA + p_ptr * 64, each byte four two-bit pixels, most significant first, value 0 transparent and 1 / 2 / 3 the
BBC colours 1 / 2 / 3 (the same indices as the tiles), each pixel two Super Hi-Res pixels wide; lower-numbered sprites are in
front. The display has no fine scroll, so t_xs is taken off the x position. All sprite positions must be even (a pixel is then a
whole byte): this is asserted."""
import make_apple2gs_tiles as conv


def matrix_picture(mem, base, sym, lb):
    matrix = sym["MAT_B"] if mem[base + lb["cur_buf"]] else sym["MAT_A"]
    out = bytearray()
    for r in range(25):
        lines = [bytearray() for _ in range(8)]
        for c in range(40):
            code = mem[base + matrix + r * 40 + c]
            for i in range(8):
                lines[i] += conv.shr_line(mem[base + sym["BPAT"] + i * 256 + code])
        for ln in lines:
            out += ln
    return out


def sprite_boxes(mem, base, sym, lb):
    """[(k, x, y, image address)] of the enabled sprites, on-screen coordinates (x, y may be negative)."""
    en, msb, txs = mem[base + lb["p_en"]], mem[base + lb["p_msb"]], mem[base + lb["t_xs"]]
    boxes = []
    for k in range(8):
        if not en >> k & 1:
            continue
        x = mem[base + lb["p_sx"] + k] | ((msb >> k & 1) << 8)
        boxes.append((k, x - 24 - txs, mem[base + lb["p_sy"] + k] - 50, sym["SPRAREA"] + mem[base + lb["p_ptr"] + k] * 64))
    return boxes


def picture(mem, base, sym, lb):
    screen = matrix_picture(mem, base, sym, lb)
    for k, x, y, image in sorted(sprite_boxes(mem, base, sym, lb), reverse=True):    # 7 first, 0 last: sprite 0 in front
        if not -24 <= x < 320 or not -21 <= y < 200:
            continue                                            # the layer skips sprites wholly off the picture
        assert x % 2 == 0, f"sprite {k} at odd x {x}: the layer draws whole bytes"
        for line in range(21):
            yy = y + line
            if not 0 <= yy < 200:
                continue
            for byte in range(3):
                b = mem[base + image + line * 3 + byte]
                for p in range(4):
                    v = b >> (6 - 2 * p) & 3
                    col = x // 2 + byte * 4 + p
                    if v and 0 <= col < 160:
                        screen[yy * 160 + col] = v * 17
    return bytes(screen)
