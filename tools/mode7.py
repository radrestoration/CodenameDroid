#!/usr/bin/env python3
"""The disc's MODE 7 instruction pages (lines 100-790 of its BASIC program DROID), run by a small interpreter of just the
statements they use (PRINT with TAB, CHR$, SPC, ' and ;, VDU 28 text windows, CLS, MODE 7, a REPEAT UNTIL GET=32 at the
end of each page) on a 40 x 25 teletext screen, then turned into C64 text-mode pages.   mode7.py DROID  (lists them)

Teletext: a control code (128-159) takes a cell; the attributes it sets (colours 129-135, flash 136, steady 137, normal
and double height 140/141, black and 'new' background 156/157) apply along its row from that cell on (foreground colour
and flash from the next cell), and reset at the start of each row. Codes 160 up show as the character 32 below them.
On the C64: foreground colours map to C64 colours, a background colour is reverse video in that colour (the letters
become holes in it), flash and double height are not done (the title is one row: the second row of a double height pair is left blank)."""
import re
import sys
import os

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import detok  # noqa: E402

COLS, ROWS = 40, 25
# teletext colours 1-7: red green yellow blue magenta cyan white -> C64 colours (blue light: the C64's is too dark for text)
C64 = {0: 0, 1: 2, 2: 5, 3: 7, 4: 14, 5: 4, 6: 3, 7: 1}


class Screen:
    def __init__(self):
        self.mode7()

    def mode7(self):
        self.cells = [[32] * COLS for _ in range(ROWS)]
        self.win = (0, ROWS - 1, COLS - 1, 0)           # left, bottom, right, top
        self.r, self.c = 0, 0

    def home(self):
        self.r, self.c = self.win[3], self.win[0]

    def cls(self):
        l, b, r, t = self.win
        for y in range(t, b + 1):
            for x in range(l, r + 1):
                self.cells[y][x] = 32
        self.home()

    def newline(self):
        l, b, r, t = self.win
        self.c = l
        self.r += 1
        if self.r > b:
            for y in range(t, b):
                self.cells[y][l:r + 1] = self.cells[y + 1][l:r + 1]
            self.cells[b][l:r + 1] = [32] * (r - l + 1)
            self.r = b

    def put(self, ch):
        self.cells[self.r][self.c] = ch
        self.c += 1
        if self.c > self.win[2]:
            self.newline()

    def tab(self, x, y=None):
        self.c = self.win[0] + x
        if y is not None:
            self.r = self.win[3] + y


def split_statements(line):
    out, cur, q = [], "", False
    for ch in line:
        if ch == '"':
            q = not q
        if ch == ":" and not q:
            out.append(cur)
            cur = ""
        else:
            cur += ch
    out.append(cur)
    return out


def string_bytes(s):
    return bytes(int(m.group(1), 16) if m.group(1) else ord(m.group(2)) for m in re.finditer(r"\\x([0-9a-f]{2})|(.)", s))


def do_print(scr, args):
    i, newline = 0, True
    while i < len(args):
        ch = args[i]
        newline = True
        if ch == '"':
            j = args.index('"', i + 1)
            for b in string_bytes(args[i + 1:j]):
                scr.put(b)
            i = j + 1
        elif ch == "'":
            scr.newline()
            i += 1
        elif ch == ";":
            newline = False
            i += 1
        elif args.startswith("TAB(", i):
            j = args.index(")", i)
            v = [int(x) for x in args[i + 4:j].split(",")]
            scr.tab(*v)
            i = j + 1
        elif args.startswith("CHR$", i):
            m = re.match(r"CHR\$(\d+)", args[i:])
            scr.put(int(m.group(1)))
            i += m.end()
        elif args.startswith("SPC(", i):
            j = args.index(")", i)
            for _ in range(int(args[i + 4:j])):
                scr.put(32)
            i = j + 1
        else:
            raise SystemExit("PRINT: cannot read %r" % args[i:])
    if newline:
        scr.newline()


def run(path):
    """The screens (40 x 25 lists of codes) at each wait for SPACE."""
    scr, pages = Screen(), []
    prog = {ln: t for ln, t in detok.lines(path)}
    loop = None
    for ln in sorted(prog):
        if ln < 100 or ln > 790:
            continue
        stmts = split_statements(prog[ln].strip())
        k = 0
        while k < len(stmts):
            st = stmts[k].strip()
            k += 1
            if st.startswith("*") or st.startswith("REM") or st.startswith("ONERROR") or not st:
                continue
            if st.startswith("MODE7"):
                scr.mode7()
            elif st.startswith("VDU23"):
                pass
            elif st.startswith("VDU28"):
                l, b, r, t = [int(x) for x in st[6:].split(",")]
                scr.win = (l, b, r, t)
                scr.home()
            elif st == "CLS":
                scr.cls()
            elif st.startswith("PRINT"):
                do_print(scr, st[5:])
            elif st.startswith("FORA%"):
                loop = (k, int(re.search(r"=(\d+)TO(\d+)", st).group(2)), 1)
            elif st.startswith("NEXT"):
                k0, n, i = loop
                if i < n:
                    loop = (k0, n, i + 1)
                    k = k0
            elif st.startswith("REPEATUNTILGET=32"):
                pages.append([row[:] for row in scr.cells])
            elif st == "RETURN":
                return pages
            else:
                raise SystemExit("line %d: cannot run %r" % (ln, st))
    return pages


def row_attrs(row):
    """For each cell of a teletext row: (code shown, foreground 0-7, background 0-7)."""
    fg, bg, out = 7, 0, []
    for code in row:
        shown = code
        if code >= 128 and code < 160:
            if 129 <= code <= 135:
                fg_next = code - 128
            else:
                fg_next = fg
            if code == 157:
                bg = fg
            elif code == 156:
                bg = 0
            out.append((32, fg, bg))
            fg = fg_next
            continue
        if code >= 160:
            shown = code & 0x7f
        out.append((shown, fg, bg))
    return out


def screen_code(ch):
    """The C64's screen code (lower case character set) for an ASCII character."""
    if 97 <= ch <= 122:
        return ch - 96
    if ch == 64:
        return 0
    if ch in (91, 92, 93, 94, 95):
        return ch - 64
    return ch


def c64_page(cells):
    """The page as runs (row, column, C64 colour, screen codes), double height pairs reduced to one row of text."""
    runs = []
    dbl_prev = False
    for y, row in enumerate(cells):
        attrs = row_attrs(row)
        dbl = any(c == 141 for c in row)
        second = dbl and dbl_prev
        dbl_prev = dbl
        if second:
            continue                            # (the second row of a double height line: nothing)
        cur = None
        for x, (shown, fg, bg) in enumerate(attrs):
            ch = 32 if second else shown
            code = screen_code(ch)
            if bg:
                colour, code = C64[bg], code | 128
            elif ch == 32:
                colour = None                   # (a space on the background: nothing to draw)
            else:
                colour = C64[fg]
            if colour is None:
                if cur and cur[3]:
                    cur[3].append(32)           # spaces inside a run of text stay in it (trimmed later)
                continue
            if cur and cur[2] == colour:
                cur[3].append(code)
            else:
                if cur:
                    runs.append(cur)
                cur = [y, x, colour, bytearray([code])]
        if cur:
            runs.append(cur)
        # (trailing spaces on a run are dropped; a run of only spaces is not a run)
    out = []
    for y, x, colour, b in runs:
        while b and b[-1] == 32:
            b.pop()
        if b:
            assert 0 not in b, "a screen code 0 would end the table entry"
            out.append((y, x, colour, bytes(b)))
    return out


def main(path):
    pages = run(path)
    print(len(pages), "pages")
    for n, p in enumerate(pages):
        print("--- page", n + 1)
        for row in p:
            print("".join(chr(c) if 32 <= c < 127 else "¤" if c >= 128 and c < 160 else (chr(c & 0x7f) if c >= 160 else "?") for c in row).rstrip())


if __name__ == "__main__":
    main(sys.argv[1])
