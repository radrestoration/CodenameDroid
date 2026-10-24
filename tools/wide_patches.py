"""Patches that make the game's screen geometry a parameter: the ring (its screen buffer) is 32 rows of W cells, W = 32
as on the BBC or 40 to fill the C64's screen.

The BBC game has the ring's geometry spread through its code: a row of cells is exactly one page ($100 bytes), the ring
ends at $8000 where a sign test wraps it, and window-relative constants all assume 32 columns. This module changes
those places, each addressed by its line in the pristine droid.s with its old text asserted, so a changed source or a
wrong edit fails loudly. Nothing may move: every edit keeps the size of what it replaces (a call to a helper in the
engine plus NOPs when more room is needed), because the game has absolute addresses into its own code.

apply(text, W, force) returns (text, helpers): the patched source and the assembler text of the helper routines it
calls (ring_ops, included by c64.s). W = 32 changes nothing unless force (the BBC geometry through the same patches:
the tests use that to show the patches themselves keep the game's behaviour).
"""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "bbc", "src")


class Edit(Exception):
    pass


def strip_comment(s):
    return re.sub(r"\s*;.*$", "", s).rstrip()


def load_symbols():
    syms = {}
    for line in open(os.path.join(SRC, "symbols.inc")):
        m = re.match(r"^(\w+)\s*=\s*\$([0-9a-fA-F]+)", line)
        if m:
            syms[m.group(1)] = int(m.group(2), 16)
    return syms


SYMS = load_symbols()
IMPLIED = {"clc", "sec", "cli", "sei", "cld", "sed", "clv", "rts", "rti", "nop", "tax", "tay", "txa", "tya", "tsx", "txs",
           "pha", "pla", "php", "plp", "inx", "iny", "dex", "dey", "brk"}
BRANCH = {"bcc", "bcs", "beq", "bmi", "bne", "bpl", "bvc", "bvs"}


def is_zp(op):
    """Is this operand symbol/number a zero-page address?"""
    op = op.strip()
    m = re.match(r"^\$([0-9a-fA-F]+)$", op)
    if m:
        return len(m.group(1)) <= 2
    base = re.split(r"[+-]", op)[0].strip()
    return base in SYMS and SYMS[base] < 256


def size_of(line):
    """Bytes of one source line of the game (instruction, label or a .res/.byte)."""
    s = strip_comment(line).strip()
    if not s or s.endswith(":"):
        return 0
    m = re.match(r"\.res\s+(\d+)", s)
    if m:
        return int(m.group(1))
    if s.startswith(".byte"):
        return len(s[5:].split(","))
    parts = s.split(None, 1)
    mn = parts[0].lower()
    op = parts[1].strip() if len(parts) > 1 else ""
    if mn in IMPLIED or (mn in ("asl", "lsr", "rol", "ror") and (op == "" or op.lower() == "a")):
        return 1
    if mn in BRANCH:
        return 2
    if mn in ("jsr", "jmp"):
        return 3
    if op.startswith("#"):
        return 2
    if op.startswith("("):
        return 2                                   # (zp),y and (zp,x)
    m = re.match(r"^(.*),\s*([xy])$", op, re.I)
    base = m.group(1) if m else op
    return 2 if is_zp(base) else 3


def size_of_lines(lines):
    return sum(size_of(l) for l in lines)


class Patcher:
    def __init__(self, text, W):
        self.L = text.split("\n")
        self.W = W
        self.S = 8 * W                  # bytes from a cell to the one below it
        self.RING_SZ = 32 * self.S
        self.RING = 0x8000 - self.RING_SZ
        self.RING_HI = (0x8000 - self.RING_SZ) >> 8
        self.SZ_HI = self.RING_SZ >> 8
        self.edits = []                 # (first, last, new lines), 1-based inclusive
        self.pairs = []                 # what pair() decided, for review
        self.helpers = []
        self.hnames = {}

    # ---- checks -------------------------------------------------------------------------------------------------
    def line(self, n):
        return self.L[n - 1]

    def expect(self, n, pattern):
        if not re.search(pattern, strip_comment(self.line(n))):
            raise Edit("line %d: expected /%s/, found %r" % (n, pattern, self.line(n)))

    # ---- edits (applied together, from the bottom, by apply_edits) -------------------------------------------------
    def replace_line(self, n, old_regex, new_text):
        """Replace the instruction on line n (checked against old_regex) with new_text (the same size)."""
        self.expect(n, old_regex)
        old = self.line(n)
        com = re.search(r"\s*;.*$", old)
        new = new_text + (com.group(0) if com else "")
        if size_of(new_text) != size_of(old):
            raise Edit("line %d: size changes (%d -> %d)" % (n, size_of(old), size_of(new_text)))
        self.edits.append((n, n, [new]))

    def imm(self, n, old, new, ops=("adc", "sbc", "cmp", "lda", "ldx", "ldy")):
        """Change the immediate operand on line n from old to new (ints or strings for symbols)."""
        o = old if isinstance(old, str) else "$%02x" % old
        self.expect(n, r"\b(%s) #%s$" % ("|".join(ops), re.escape(o)))
        nw = new if isinstance(new, str) else "$%02x" % new
        self.L[n - 1] = re.sub(r"#%s\b" % re.escape(o), "#" + nw, self.L[n - 1], count=1)

    def lda_pair(self, lo_line, hi_line, log=None):
        """As pair, for two LDA immediates (an offset about to be stored)."""
        return self.pair(lo_line, hi_line, op="lda")

    def pair(self, lo_line, hi_line, op="adc", log=None):
        """A 16-bit address offset made of two immediates (low on lo_line, high on hi_line, carry linking them): v =
        rows * 256 + cells * 8 + lines in the BBC's ring becomes rows * S + cells * 8 + lines here."""
        mlo = re.search(r"\b%s #\$([0-9a-f]{2})$" % op, strip_comment(self.line(lo_line)))
        mhi = re.search(r"\b%s #\$([0-9a-f]{2})$" % op, strip_comment(self.line(hi_line)))
        if not mlo or not mhi:
            raise Edit("pair %d/%d: not %s immediates: %r %r" % (lo_line, hi_line, op, self.line(lo_line), self.line(hi_line)))
        v = int(mhi.group(1), 16) * 256 + int(mlo.group(1), 16)
        rows, cells, lines = decompose(v)
        lo, hi = self.off16(rows, cells, lines)
        if self.W == 32 and (lo, hi) != (v & 255, v >> 8):
            raise Edit("pair %d/%d: decomposition of %04x does not reproduce it" % (lo_line, hi_line, v))
        self.L[lo_line - 1] = re.sub(r"#\$[0-9a-f]{2}", "#$%02x" % lo, self.L[lo_line - 1], count=1)
        self.L[hi_line - 1] = re.sub(r"#\$[0-9a-f]{2}", "#$%02x" % hi, self.L[hi_line - 1], count=1)
        self.pairs.append((lo_line, hi_line, op, v, (rows, cells, lines), (lo, hi)))

    def pair_lo_only(self, lo_line, old_v, hi_line):
        """A low immediate (lda) whose high byte was set by an earlier pair (hi_line, already patched): the new offset must
        have the same high byte as that one has now."""
        mlo = re.search(r"\blda #\$([0-9a-f]{2})$", strip_comment(self.line(lo_line)))
        mhi = re.search(r"\blda #\$([0-9a-f]{2})$", strip_comment(self.line(hi_line)))
        if not mlo:
            raise Edit("pair_lo_only %d: not an lda immediate" % lo_line)
        rows, cells, lines = decompose(old_v)
        lo, hi = self.off16(rows, cells, lines)
        if int(mhi.group(1), 16) != hi:
            raise Edit("pair_lo_only %d: its high byte would be %02x, the line before has %s" % (lo_line, hi, mhi.group(1)))
        self.L[lo_line - 1] = re.sub(r"#\$[0-9a-f]{2}", "#$%02x" % lo, self.L[lo_line - 1], count=1)

    def abs_pair(self, lo_line, hi_line, old_abs, new_abs, op="lda"):
        """Two immediates that make an absolute address in the ring (low on lo_line, high on hi_line): the old one asserted."""
        mlo = re.search(r"\b%s #\$([0-9a-f]{2})$" % op, strip_comment(self.line(lo_line)))
        mhi = re.search(r"\b%s #\$([0-9a-f]{2})$" % op, strip_comment(self.line(hi_line)))
        if not mlo or not mhi or int(mhi.group(1), 16) * 256 + int(mlo.group(1), 16) != old_abs:
            raise Edit("abs_pair %d/%d: not %s #%04x" % (lo_line, hi_line, op, old_abs))
        if self.W == 32 and new_abs != old_abs:
            raise Edit("abs_pair %d/%d: %04x would become %04x at 32 columns" % (lo_line, hi_line, old_abs, new_abs))
        self.L[lo_line - 1] = re.sub(r"#\$[0-9a-f]{2}", "#$%02x" % (new_abs & 255), self.L[lo_line - 1], count=1)
        self.L[hi_line - 1] = re.sub(r"#\$[0-9a-f]{2}", "#$%02x" % (new_abs >> 8), self.L[hi_line - 1], count=1)

    def byte_hi(self, n, old_hi, expr):
        """The high byte of a `.byte lo,hi` pair (an address in a table) becomes the expression expr."""
        m = re.match(r"^(\s+\.byte \$[0-9a-f]{2},)\$%02x(\s*.*)$" % old_hi, self.line(n))
        if not m:
            raise Edit("line %d: not a .byte pair ending $%02x: %r" % (n, old_hi, self.line(n)))
        self.L[n - 1] = "%s%s%s" % (m.group(1), expr, m.group(2))

    def src_lines_of(self, rel):
        """The lines of a file of the BBC source (rel is relative to the repository root)."""
        return open(os.path.join(SRC, "..", rel)).read().split("\n")

    def explicit_pair(self, lo_line, hi_line, lo, hi, old_v, op="adc"):
        """As pair, but the new offset is given (the old one asserted)."""
        mlo = re.search(r"\b%s #\$([0-9a-f]{2})$" % op, strip_comment(self.line(lo_line)))
        mhi = re.search(r"\b%s #\$([0-9a-f]{2})$" % op, strip_comment(self.line(hi_line)))
        if not mlo or not mhi or int(mhi.group(1), 16) * 256 + int(mlo.group(1), 16) != old_v:
            raise Edit("explicit pair %d/%d: not %s #%04x" % (lo_line, hi_line, op, old_v))
        self.L[lo_line - 1] = re.sub(r"#\$[0-9a-f]{2}", "#$%02x" % lo, self.L[lo_line - 1], count=1)
        self.L[hi_line - 1] = re.sub(r"#\$[0-9a-f]{2}", "#$%02x" % hi, self.L[hi_line - 1], count=1)

    def block_hash(self, first, last, digest, new_lines, pad=True):
        """As block, for a long stretch of code: its instructions (comments stripped, one per line) are checked by their
        SHA-1 instead of being listed."""
        import hashlib
        old = self.L[first - 1:last]
        got = hashlib.sha1("\n".join(strip_comment(l).strip() for l in old).encode()).hexdigest()[:12]
        if got != digest:
            raise Edit("block %d-%d: its code is not the expected one (%s, not %s)" % (first, last, got, digest))
        so, sn = size_of_lines(old), size_of_lines(new_lines)
        if sn > so:
            raise Edit("block %d-%d: new code is %d bytes, old %d" % (first, last, sn, so))
        out = list(new_lines)
        if sn < so and pad:
            out.append("    .res %d, $ea                    ; (the BBC's code was longer)" % (so - sn))
        out += [l for l in old if re.match(r"^\w+:\s*(;.*)?$", l)]
        self.edits.append((first, last, out))

    def block(self, first, last, expect_lines, new_lines, pad=True):
        """Replace lines first..last (their instructions checked) with new_lines, NOP-padded to the same size."""
        old = self.L[first - 1:last]
        if len(old) != len(expect_lines):
            raise Edit("block %d-%d: %d lines, %d expected" % (first, last, len(old), len(expect_lines)))
        for k, (o, e) in enumerate(zip(old, expect_lines)):
            if strip_comment(o).strip() != e.strip():
                raise Edit("block %d-%d line %d: expected %r, found %r" % (first, last, first + k, e, strip_comment(o)))
        so, sn = size_of_lines(old), size_of_lines(new_lines)
        if sn > so:
            raise Edit("block %d-%d: new code is %d bytes, old %d" % (first, last, sn, so))
        out = list(new_lines)
        if sn < so and pad:
            out.append("    .res %d, $ea                    ; (the BBC's code was longer)" % (so - sn))
        out += [l for l in old if re.match(r"^\w+:\s*(;.*)?$", l)]       # (a label inside the block may be referenced)
        self.edits.append((first, last, out))

    # ---- helper routines -------------------------------------------------------------------------------------------
    def helper(self, key, body):
        """Register a helper routine (ca65 text) once per key; returns its label."""
        if key not in self.hnames:
            name = "wide_%s" % key
            self.hnames[key] = name
            self.helpers.append("%s:\n%s\n" % (name, body.rstrip("\n")))
        return self.hnames[key]

    def call(self, key, body):
        """A call of the helper key (registered with body) as a source line."""
        return "    jsr %s" % self.helper(key, body)

    def finish(self):
        for first, last, new in sorted(self.edits, key=lambda e: -e[0]):
            self.L[first - 1:last] = new
        return "\n".join(self.L), '.segment "CODE"\n\n' + "\n".join(self.helpers)

    # ---- geometry --------------------------------------------------------------------------------------------------
    def off16(self, rows, cells=0, lines=0):
        """The 16-bit address offset of rows cell rows, cells cells and lines lines, as (lo, hi)."""
        v = (rows * self.S + cells * 8 + lines) & 0xffff
        return v & 255, v >> 8


def decompose(v, old_w=32):
    """Split a 16-bit address offset of the BBC's 32-column ring (as the sum of a high and low immediate) into cell rows,
    cells and lines, taking the fewest cells off the row: v = rows * 256 + cells * 8 + lines, lines 0-7, |cells| < 16."""
    lines = v & 7
    cells = (v >> 3) & 31 if True else 0
    # cells in [-16, 16)
    c = ((v - lines) >> 3)
    rows = round(c / 32)
    cells = c - rows * 32
    return rows, cells, lines


def apply(text, W, force=False):
    if W == 32 and not force:
        return text, ""
    p = Patcher(text, W)
    build(p)
    if os.environ.get("WIDE_LOG"):
        for lo, hi, op, v, d, new in p.pairs:
            print("pair %d/%d %s %04x = %d rows %+d cells %d lines -> %02x %02x" % (lo, hi, op, v, d[0], d[1], d[2], new[0], new[1]))
    return p.finish()


def build(p):
    """All the patches. Sites are given by line number in the pristine droid.s."""
    from wide_sites import sites
    sites(p)
