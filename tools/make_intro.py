#!/usr/bin/env python3
"""The loading screens (src/intro.s) from the original disc: build/c64/gen/intro_data.s.

The BBC disc's front end shows, first, the MODE 7 instruction pages (the BASIC program DROID: tools/mode7.py runs its
PRINT statements on a teletext screen and makes C64 text pages of them, in the C64's own character set), then, from the
BASIC program CDroid, in MODE 1 (320 x 256, four colours):
  CDroid1  the logo (184 rows, the rest black), palette black / red / blue / white
  CDroid2  a full screen picture, palette black / red / cyan / white
  CDroid3  a 40-row strip of the logo (at text row 2), shown under "PRESENTING" with the credits text; the program
           flashes its logical colour 2 between blue and green once a frame, which leaves it green
and text in capitals the program redefines (VDU 23 in its listing); its digits and punctuation are the OS's, which are
not here: the C64's own character ROM supplies them when the page is shown.

On the C64 the pictures are multicolour bitmaps, 160 x 200: the 320 x 256 screen is scaled (area average, then
Floyd-Steinberg to the three colours and black) so that nothing is cropped; the three colours are the same in every cell
(screen RAM holds two, colour RAM the third), so only the 8000 bitmap bytes are stored, compressed (LZ77, see
compress()). The logo and the strip keep their rows and halve their width without dithering (halve()). The strip is made into multicolour characters; the credits text is the redefined capitals in a hires
character set, the same screen showing both (colour RAM bit 3).

Input: the disc image (DISC), found by the Makefile. Without it an intro_data.s with INTRO_PRESENT = 0 is written and the
build has no loading screens.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "bbc", "tools"))

BBC = {0: (0, 0, 0), 1: (255, 0, 0), 2: (0, 255, 0), 3: (255, 255, 0), 4: (0, 0, 255), 5: (255, 0, 255), 6: (0, 255, 255),
       7: (255, 255, 255)}
C64_BLUE, C64_CYAN, C64_RED, C64_GREEN, C64_WHITE = 14, 3, 2, 5, 1      # (light blue: the C64's blue is too dark for text)


def mode1(data):
    """The MODE 1 screen bytes (cells of 8 bytes, 80 to a row) as an array of logical colours 0-3, rows x 320."""
    import numpy as np
    rows = len(data) // 640
    img = np.zeros((rows * 8, 320), np.uint8)
    for cy in range(rows):
        for cx in range(80):
            for ln in range(8):
                b = data[(cy * 80 + cx) * 8 + ln]
                for p in range(4):
                    img[cy * 8 + ln, cx * 4 + p] = ((b >> (7 - p)) & 1) << 1 | ((b >> (3 - p)) & 1)
    return img


def quantise(a, pal):
    """Floyd-Steinberg of the float image a (H x W x 3) to the palette (4 x 3): indices."""
    import numpy as np
    h, w, _ = a.shape
    a = a.copy()
    out = np.zeros((h, w), np.uint8)
    for y in range(h):
        for x in range(w):
            old = a[y, x]
            k = int(np.argmin(((pal - old) ** 2).sum(1)))
            out[y, x] = k
            err = old - pal[k]
            if x + 1 < w:
                a[y, x + 1] += err * 7 / 16
            if y + 1 < h:
                if x > 0:
                    a[y + 1, x - 1] += err * 3 / 16
                a[y + 1, x] += err * 5 / 16
                if x + 1 < w:
                    a[y + 1, x + 1] += err / 16
    return out


def halve(img):
    """A MODE 1 image of logical colours, two pixels across to one, without dithering. Of two different colours the first
    of red (1), the second colour (2), white (3), black (0) wins: the red outlines of the logo stay whole, and strokes keep
    their width."""
    import numpy as np
    rank = np.array([3, 0, 1, 2])                           # (by colour: lower wins)
    a, b = img[:, 0::2], img[:, 1::2]
    return np.where(rank[a] <= rank[b], a, b).astype(np.uint8)


def to_mc(idx):
    """Pixel codes (H x 160, values 0-3) as the C64's bitmap bytes: cells of 8 bytes, 40 to a row."""
    out = bytearray()
    for cy in range(idx.shape[0] // 8):
        for cx in range(40):
            for ln in range(8):
                r = idx[cy * 8 + ln, cx * 4:cx * 4 + 4]
                out.append(int(r[0]) << 6 | int(r[1]) << 4 | int(r[2]) << 2 | int(r[3]))
    return bytes(out)


SPLIT_ROW = 13          # the logo screen: cell rows from here down are hires (raster line 51 + 8 * 13 = 155)


def logo_picture(data, pal):
    """The logo screen (184 rows) as C64 bitmap bytes and screen RAM bytes, in two parts that the loading screens'
    code switches between with the raster: above cell row SPLIT_ROW the logo's letters, multicolour (160 wide, the three
    colours the same in every cell: screen RAM $26 and white colour RAM); from there down hires (320 wide, which keeps the
    white text sharp), where each 8 x 8 cell has the two colours (of black, red, blue, white) that fit its pixels best."""
    import itertools
    import numpy as np
    img = mode1(data)
    full = np.zeros((200, 320), np.uint8)
    top = (200 - img.shape[0]) // 2
    full[top:top + img.shape[0]] = img
    c64 = [0, C64_RED, 6, C64_WHITE]                       # (the C64's colours for the logical ones: black, red, blue, white)
    rgb = np.array([BBC[p] for p in pal], float)
    cost = ((rgb[:, None, :] - rgb[None, :, :]) ** 2).sum(2) / 65025.0       # of showing one colour where there is another
    bm, scr = bytearray(), bytearray()
    mc = to_mc(halve(full[:SPLIT_ROW * 8]))
    for cy in range(25):
        for cx in range(40):
            if cy < SPLIT_ROW:
                bm += mc[(cy * 40 + cx) * 8:(cy * 40 + cx) * 8 + 8]
                scr.append(C64_RED << 4 | 6)
                continue
            cell = full[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8]
            cnt = np.bincount(cell.ravel(), minlength=4)
            best = min(((sum(cnt[c] * min(cost[c, a], cost[c, b]) for c in range(4)), a, b)
                        for a, b in itertools.combinations(range(4), 2)))
            _, a, b = best                                  # (a < b: black, when there is one, is a)
            for ln in range(8):
                byte = 0
                for x in range(8):
                    c = cell[ln, x]
                    byte = byte << 1 | (1 if cost[c, b] < cost[c, a] else 0)
                bm.append(byte)
            scr.append(c64[b] << 4 | c64[a])
    return bytes(bm), bytes(scr)


def scroll_picture(data, pal):
    """The full screen picture (320 x 256) for the loading screens' slow scroll: all 256 rows, two pixels across to one
    (halve(): no dithering, which suits it far better than it did the squeezed version). As C64 multicolour bitmap bytes:
    (the first 25 cell rows, 8000 bytes; the other 7 and a blank one, 2560 bytes: the scroll takes them in a row at a time)."""
    img = mode1(data)
    bm = to_mc(halve(img))
    assert len(bm) == 32 * 320
    return bm[:8000], bm[8000:] + bytes(320)


def picture(data, pal):
    """A MODE 1 screen (320 x up to 256) as 160 x 200 C64 multicolour bitmap bytes: scaled to 200 rows (the logo has its
    own, logo_picture())."""
    import numpy as np
    from PIL import Image
    img = mode1(data)
    rgb = np.array([BBC[p] for p in pal], float)
    full = np.zeros((256, 320), np.uint8)
    full[:img.shape[0]] = img
    small = np.asarray(Image.fromarray(rgb[full].astype(np.uint8)).resize((160, 200), Image.BOX), float)
    return to_mc(quantise(small, rgb))


def compress(data):
    """LZ77, parsed for the smallest result:
         0nnnnnnn          n + 1 literal bytes follow (1-128)
         100lllll oooooooo copy l + 3 bytes (3-34) from o + 1 bytes back (1-256)
         11llllll lo hi    copy l + 4 bytes (4-67) from lo + hi * 256 bytes back
       (a copy may overlap the bytes being written)"""
    n = len(data)
    heads = {}
    near = [None] * n               # at each position: {length: nearest offset}
    for i in range(n):
        best = {}
        for j in reversed(heads.get(bytes(data[i:i + 3]), [])[-300:]):
            ln = 0
            while i + ln < n and ln < 67 and data[j + ln] == data[i + ln]:
                ln += 1
            for l in range(3, ln + 1):
                best.setdefault(l, i - j)
        near[i] = best
        heads.setdefault(bytes(data[i:i + 3]), []).append(i)
    inf = float("inf")
    # M[i], L[i]: the cheapest way to have written the first i bytes ending with a copy, or with a run of literals
    M, L = [inf] * (n + 1), [inf] * (n + 1)
    fromM, fromL = [None] * (n + 1), [None] * (n + 1)
    M[0] = 0
    for i in range(n):
        base = min(M[i], L[i])
        if base == inf:
            continue
        for k in range(1, min(128, n - i) + 1):                # a run of k literals: a token and k bytes
            c = base + 1 + k
            if c < L[i + k]:
                L[i + k], fromL[i + k] = c, (i, k)
        for l, off in near[i].items():
            if off <= 256 and l <= 34:
                c = base + 2
            elif l >= 4:
                c = base + 3
            else:
                continue
            if c < M[i + l]:
                M[i + l], fromM[i + l] = c, (i, l, off)
    steps = []
    i, last = n, ("M" if M[n] <= L[n] else "L")
    while i > 0:
        if last == "M":
            j, l, off = fromM[i]
            steps.append((l, off))
            i = j
        else:
            j, k = fromL[i]
            steps.extend([None] * k)
            i = j
        last = "M" if M[i] <= L[i] else "L"
    steps.reverse()
    out, lit, i = bytearray(), bytearray(), 0

    def flush():
        k = 0
        while k < len(lit):
            m = min(128, len(lit) - k)
            out.append(m - 1)
            out.extend(lit[k:k + m])
            k += m
        lit.clear()
    for h in steps:
        if h is None:
            lit.append(data[i])
            i += 1
            continue
        flush()
        l, off = h
        if off <= 256 and l <= 34:
            out.append(0x80 | (l - 3))
            out.append(off - 1)
        else:
            out.append(0xc0 | (l - 4))
            out.append(off & 255)
            out.append(off >> 8)
        i += l
    flush()
    return bytes(out)


def decompress(comp, size):
    out = bytearray()
    i = 0
    while len(out) < size:
        t = comp[i]
        i += 1
        if t < 128:
            out.extend(comp[i:i + t + 1])
            i += t + 1
            continue
        if t & 0x40:
            ln, off = (t & 63) + 4, comp[i] | comp[i + 1] << 8
            i += 2
        else:
            ln, off = (t & 31) + 3, comp[i] + 1
            i += 1
        for _ in range(ln):
            out.append(out[-off])
    assert len(out) == size
    return bytes(out)


def basic_font(program):
    """The glyphs the loader defines with VDU 23,n,b1..b8 (from its BASIC listing): {code: 8 bytes}."""
    import io
    import contextlib
    import detok
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        detok.main(program)
    glyphs = {}
    for line in buf.getvalue().split("\n"):
        text = line.split(" ", 1)[1] if " " in line else ""
        text = text.strip()
        if text.startswith("VDU23,") and text.count(",") == 9:
            v = [int(x) for x in text[6:].split(",")]
            glyphs[v[0]] = bytes(v[1:])
    return glyphs


def strip_chars(data, pal):
    """CDroid3 (a 320 x 40 strip) as multicolour characters: (the distinct 8-byte patterns, 40 x 5 indices)."""
    import numpy as np
    from PIL import Image
    img = mode1(data)
    bm = to_mc(halve(img))
    pats, cells = [], []
    for k in range(len(bm) // 8):
        p = bm[k * 8:k * 8 + 8]
        if p not in pats:
            pats.append(p)
        cells.append(pats.index(p))
    return pats, cells


TEXT_PAGES = {   # the credits and the controls: (row, column, colour, text); the characters are the credits' character set's
    'credits': [
        (0, 15, 1, 'PRESENTING'),
        (9, 13, 2, 'PROGRAMMING BY'),
        (11, 12, 1, 'NICK CHAMBERLAIN'),
        (13, 18, 1, 'AND'),
        (15, 12, 1, 'MARTIN EDMONDSON'),
        (18, 10, 2, 'FOR SUPERIOR SOFTWARE'),
        (20, 17, 2, '@ ^_B['),
        (23, 3, 5, "PRESS V TO VIEW STRYKER'S CONTROLS"),
        (24, 10, 5, 'PRESS SPACE TO LOAD'),
    ],
    'keys': [
        (0, 5, 2, 'THE CONTROLS ARE AS FOLLOWS'),
        (2, 13, 1, 'RUN RIGHT - X'),
        (3, 14, 1, 'RUN LEFT - Z'),
        (4, 10, 1, 'FIRE BLASTER - ='),
        (5, 6, 1, 'ASCEND ROPE/LIFT - ;'),
        (6, 18, 1, 'JUMP - RETURN'),
        (7, 1, 1, 'KNEEL, CRAWL, DESCEND - /'),
        (9, 11, 1, 'DROP A MINE - D'),
        (10, 1, 1, 'ACCESS WRIST TERMINAL - A'),
        (11, 5, 1, 'JET-PACK COMPUTER - J'),
        (12, 9, 1, 'EXIT JET-PACK - O'),
        (13, 11, 1, 'LOSE A LIFE - CTRL'),
        (14, 10, 1, 'RESTART GAME - RUN/STOP'),
        (15, 1, 1, 'FREEZE - P           UNFREEZE - DEL'),
        (17, 9, 2, 'INTRO SCREEN CONTROLS'),
        (18, 6, 1, 'DEPTH JUMP - J (IF OFFERED)'),
        (19, 0, 1, 'SOUND ON - F3           SOUND OFF - F1'),
        (21, 0, 2, 'JOYSTICK IN PORT 2: LEFT AND RIGHT RUN,'),
        (22, 0, 2, 'UP AND DOWN AS ; AND /, FIRE JUMPS'),
        (24, 2, 5, 'SPACE TO SEE WRIST TERMINAL CONTROLS'),
    ],
    'terminal': [
        (6, 7, 2, "STRYKER'S WRIST TERMINAL"),
        (8, 2, 1, 'DISPLAY MICRO-FILM MAPS - M'),
        (9, 2, 1, 'AND ENEMY POSITIONS'),
        (11, 9, 1, 'RECHARGE SUIT - S'),
        (13, 6, 1, 'RECHARGE BLASTER - B'),
        (15, 3, 1, 'EXIT WRIST TERMINAL - SPACE'),
        (24, 7, 5, 'PRESS SPACE TO CONTINUE'),
    ],
}


def bytes_lines(b, per=16):
    return "".join("    .byte " + ",".join("$%02x" % v for v in b[i:i + per]) + "\n" for i in range(0, len(b), per))


def find_inputs():
    return os.environ.get("DISC") or os.path.expanduser("~/retro/games/Disc032-CodenameDroidStrykersRun2.ssd")


def main(out):
    disc = find_inputs()
    if not os.path.exists(disc):
        open(out, "w").write("; generated by tools/make_intro.py\nINTRO_PRESENT = 0\n")
        print("make_intro: no disc (%s): no loading screens" % disc)
        return
    from check_build import dfs_file
    import mode7
    d = open(disc, "rb").read()
    files = {n: dfs_file(d, n) for n in ("CDroid1", "CDroid2", "CDroid3", "CDroid", "DROID")}
    prog = os.path.join(os.path.dirname(out), "CDroid.bas")
    open(prog, "wb").write(files["CDroid"])
    front = os.path.join(os.path.dirname(out), "DROID.bas")
    open(front, "wb").write(files["DROID"])
    glyphs = {c: g for c, g in basic_font(prog).items() if 32 <= c < 128}
    pats, cells = strip_chars(files["CDroid3"], (0, 1, 2, 7))        # (logical 2 is green once the program flashes it)
    assert len(pats) <= 160, "the strip needs %d characters" % len(pats)
    code = [k if k < 32 else 128 + k - 32 for k in range(len(pats))]       # (codes 0-31 and 128-255 are free)
    charset = bytearray(2048)
    for c, g in glyphs.items():
        charset[c * 8:c * 8 + 8] = g
    for k, p in enumerate(pats):
        charset[code[k] * 8:code[k] * 8 + 8] = p
    logo_bm, logo_scr = logo_picture(files["CDroid1"], (0, 1, 4, 7))
    img1, img1s = compress(logo_bm), compress(logo_scr)
    scroll = os.environ.get("WIDE") != "32"                # (the 32-cell layout has no room to scroll in: bank 1 holds the tiles)
    if scroll:
        top, extra = scroll_picture(files["CDroid2"], (0, 1, 6, 7))
        img2, img2x = compress(top), compress(extra)
    else:
        img2, img2x = compress(picture(files["CDroid2"], (0, 1, 6, 7))), b""
    chars = compress(bytes(charset))
    pages = []
    for page in (mode7.run(front) if os.environ.get("WIDE") != "32" else []):      # (the 32-cell layout has no room: its PRG is longer)
        raw = bytearray()
        for y, x, colour, text in mode7.c64_page(page):
            raw += bytes([y, x, colour]) + text + b"\0"
        raw.append(0xff)
        pages.append((compress(bytes(raw)), len(raw)))
    n7 = len(pages)
    for name in ("credits", "keys", "terminal"):             # (these use the other character set; the table is the same)
        raw = bytearray()
        for y, x, colour, text in TEXT_PAGES[name]:
            raw += bytes([y, x, colour]) + text.encode("latin1") + b"\0"
        raw.append(0xff)
        pages.append((compress(bytes(raw)), len(raw)))
    with open(out, "w") as f:
        f.write("; generated by tools/make_intro.py\nINTRO_PRESENT = 1\n")
        f.write("INTRO_PG_CREDITS = %d\nINTRO_PG_KEYS = %d\nINTRO_PG_TERMINAL = %d\n" % (n7, n7 + 1, n7 + 2))
        f.write("INTRO_COLOURS2 = $%02x          ; picture 2: red, cyan\n" % (C64_RED << 4 | C64_CYAN))
        f.write("INTRO_M7_PAGES = %d\n" % n7)
        f.write('\n.segment "INTRO"\n\nintro_img1:\n' + bytes_lines(img1) + "intro_img1s:                    ; its screen RAM\n" + bytes_lines(img1s)
                + "intro_img2:\n" + bytes_lines(img2) + "intro_img2x:                    ; (the scroll's other rows)\n" + bytes_lines(img2x or b"\0"))
        f.write("INTRO_SCROLL = %d\n" % (1 if scroll else 0))
        f.write("INTRO_SPLIT_LINE = %d             ; the raster line where the logo screen goes from multicolour to hires\n" % (51 + 8 * SPLIT_ROW))
        f.write("intro_charset_c:                ; 256 characters (the redefined capitals by ASCII code, the strip's in the rest), packed\n"
                + bytes_lines(chars))
        f.write("intro_strip_c:                  ; 40 x 5 character codes, packed (200 bytes)\n" + bytes_lines(compress(bytes(code[c] for c in cells)), 40))
        for n, (blob, size) in enumerate(pages):
            if n == 0:
                f.write('\n.segment "INTRO2"                ; (the 40-column layout puts the instruction pages in a gap)\n\n')
            if n == n7:
                f.write('\n.segment "INTRO"\n\n')
            f.write("intro_m7_%d:\n" % n + bytes_lines(blob))
        f.write("intro_m7_lo:\n    .byte " + ",".join(["<intro_m7_%d" % n for n in range(len(pages))] or ["0"]) + "\n")
        f.write("intro_m7_hi:\n    .byte " + ",".join([">intro_m7_%d" % n for n in range(len(pages))] or ["0"]) + "\n")
        f.write("intro_m7_sl:                    ; the unpacked sizes\n    .byte " + ",".join([str(sz & 255) for _, sz in pages] or ["0"]) + "\n")
        f.write("intro_m7_sh:\n    .byte " + ",".join([str(sz >> 8) for _, sz in pages] or ["0"]) + "\n")
    print("make_intro: pictures %d and %d bytes compressed, %d strip characters, charset %d, %d instruction pages in %d bytes"
          % (len(img1), len(img2), len(pats), len(chars), len(pages), sum(len(b) for b, _ in pages)))


if __name__ == "__main__":
    main(sys.argv[1])
