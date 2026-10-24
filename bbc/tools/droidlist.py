#!/usr/bin/env python3
"""Parser for codename-droid-disassembly.txt, shared by disasm_to_ca65.py
(which generates the ca65 source) and check_build.py (which compares the
assembled files against the listing's own hex bytes).

The listing has two sections, "; DROID" (the main game, loaded at &1100,
including the loader at &5800) and "; DROID2" (loaded at &6500; its
entry code at &7b00 moves its data blocks to their run addresses, and
the listing shows those blocks at the run addresses). Line forms:

    ; label                          a label for the next address line
    # text                            a comment line
    &1100 20 54 27 JSR &2754 ; sym    an instruction (bytes, mnemonic,
                                      operand, ; annotation, # comment)
    &5800 ff af ff ...  ; comment     data bytes

FIXES below are the places where the listing contradicts itself or the
original disc; each is cross-checked against the real game file on
Disc032 (see check_build.py).
"""
import re

LISTING_FIRST_LINE = 39          # "; DROID" - everything above is the preamble

MNEMONICS = set("""ADC AND ASL BCC BCS BEQ BIT BMI BNE BPL BRK BVC BVS CLC CLD CLI CLV CMP
CPX CPY DEC DEX DEY EOR INC INX INY JMP JSR LDA LDX LDY LSR NOP ORA PHA PHP
PLA PLP ROL ROR RTI RTS SBC SEC SED SEI STA STX STY TAX TAY TSX TXA TXS
TYA""".split())
BRANCHES = {"BCC", "BCS", "BEQ", "BMI", "BNE", "BPL", "BVC", "BVS"}

# Address column typos in the listing. Keys are listing line numbers,
# values (expected line prefix, correct address). In every case the
# listing's address collides with the neighbouring lines, and the game
# file on the disc has the bytes at the corrected address.
ADDRESS_FIXES = {
    6370: ("&3ae6 60 00", 0x3ae7),   # 5-entry word table at &3adf; 4th entry
    7696: ("&4bdc 80 0b", 0x4bda),   # 6-entry word table at &4bd0; 5th entry
    8212: ("&5de8 ff ff", 0x5de9),   # skeleton_sprite_three: the line above
                                     # holds its first byte (&5de8)
    8213: ("&5df8 00 00", 0x5df9),
    8672: ("&07d6 00 00", 0x07e2),   # tail of sprite_rope_section
}

# The label sits one byte before the line it precedes (the previous line's
# last byte, &5de8, is the first byte of the sprite: skeleton_sprite_addresses_table
# at &4bdc points at &5de8).
LABEL_ADDRESS_FIXES = {"skeleton_sprite_three": 0x5de8}

# Where the listing differs from the game file on Disc032, the source
# takes the disc's value (the user's decision): address -> (listing value,
# disc value, what it is). check_build.py requires the build to have the
# disc value at each of these and the listing's everywhere else.
KNOWN_DISC_DIFFS = {
    0x1201: (0xee, 0xe4, "operand high byte of LDA &e400,Y at &11ff"),
    0x51f8: (0xaa, 0x3a, "one byte of the level map"),
}

# D2's run-time blocks: (first, last, segment name). Listing order is the
# order they sit in the DROID2 file.
D2_BLOCKS = [
    (0x5800, 0x5fff, "D2_5800"),
    (0x03a0, 0x03df, "D2_03A0"),
    (0x0180, 0x01bf, "D2_0180"),
    (0x0380, 0x039f, "D2_0380"),
    (0x0300, 0x035f, "D2_0300"),
    (0x0400, 0x10ff, "D2_0400"),
    (0x7b00, 0x7bff, "D2_7B00"),
]

LABEL_RE = re.compile(r"^; ([A-Za-z0-9_]+)\s*(?:#\s*(.*))?$")
ADDR_RE = re.compile(r"^/?&([0-9a-f]{4})((?: [0-9a-f]{2})+)(?:\s+(.*))?$")
HDR_RE = re.compile(r"^; [0-9A-F]{8} [0-9A-F]{8} [0-9A-F]+$")


class Item:
    """One address line: an instruction or a run of data bytes."""

    def __init__(self, sec, lineno, addr, data, rest):
        self.sec = sec
        self.lineno = lineno
        self.addr = addr
        self.data = bytes(data)
        self.rest = rest
        self.mnem = None
        self.opstr = ""
        self.ann = ""          # text after ';'
        self.cmt = ""          # text after '#'
        self._parse_rest()

    @property
    def end(self):
        return self.addr + len(self.data)

    @property
    def is_code(self):
        return self.mnem is not None

    def _parse_rest(self):
        rest = self.rest.strip()
        toks = rest.split()
        if toks and toks[0] in MNEMONICS:
            self.mnem = toks[0]
            body = rest[3:].strip()
            # operand: up to the first whitespace; an immediate "#&xx"
            # starts with '#', a comment "# text" has a space after it
            m = re.match(r"(#&[0-9a-f]{2}|\S+)?\s*(.*)$", body)
            op, tail = m.group(1) or "", m.group(2)
            if op.startswith(";") or (op.startswith("#") and not op.startswith("#&")):
                op, tail = "", body
            self.opstr = op
        else:
            tail = rest
        # tail: [": CONST"] ["; annotation"] ["# comment"]
        tail = tail.strip()
        m = re.match(r"(?:(:\s*\S+)\s*)?(?:;\s?(.*?))?(?:\s{2,}#\s?(.*)|\s*#\s?(.*))?$", tail)
        if m is None:
            raise ValueError("line %d: cannot parse %r" % (self.lineno, tail))
        const, ann, c1, c2 = m.groups()
        self.ann = (ann or "").strip()
        self.cmt = (c1 or c2 or "").strip()
        if const:
            self.ann = (const + "  " + self.ann).strip()


class Listing:
    """stream: ordered entries (kind, payload...) as they appear:
         ("blank",)  ("comment", text)  ("label", name, cmt, lineno)
         ("item", Item)  ("section", name)  ("fileheader", text)"""

    def __init__(self, path):
        self.stream = []
        self.items = []
        lines = open(path, encoding="utf-8").read().split("\n")
        sec = None
        pending_fixed = {}
        for n, line in enumerate(lines, 1):
            if n < LISTING_FIRST_LINE:
                continue
            if line in ("; DROID", "; DROID2"):
                sec = line[2:]
                self.stream.append(("section", sec))
                continue
            if HDR_RE.match(line):
                self.stream.append(("fileheader", line[2:]))
                continue
            m = ADDR_RE.match(line)
            if m:
                addr = int(m.group(1), 16)
                if n in ADDRESS_FIXES:
                    prefix, fixed = ADDRESS_FIXES[n]
                    assert line.startswith(prefix), (n, line)
                    addr = fixed
                data = bytes.fromhex(m.group(2).replace(" ", ""))
                it = Item(sec, n, addr, data, m.group(3) or "")
                self.items.append(it)
                self.stream.append(("item", it))
                continue
            if line.strip() == "":
                self.stream.append(("blank",))
                continue
            m = LABEL_RE.match(line)
            if m:
                self.stream.append(("label", m.group(1), m.group(2) or "", n))
                continue
            if line.startswith("#") or line.lstrip().startswith(";"):
                self.stream.append(("comment", line))
                continue
            raise ValueError("line %d: unrecognised: %r" % (n, line))
        for n in ADDRESS_FIXES:
            assert any(i.lineno == n for i in self.items), n

    def labels(self):
        """[(name, address, section)] for every label line, with the
        address of the line it precedes (or its LABEL_ADDRESS_FIXES)."""
        out, pend = [], []
        for ent in self.stream:
            if ent[0] == "label":
                pend.append(ent[1])
            elif ent[0] == "item":
                for nm in pend:
                    out.append((nm, LABEL_ADDRESS_FIXES.get(nm, ent[1].addr), ent[1].sec))
                pend = []
        return out

    def images(self):
        """{section: {address: byte}} straight from the listing's hex."""
        out = {"DROID": {}, "DROID2": {}}
        for it in self.items:
            for k, b in enumerate(it.data):
                out[it.sec][it.addr + k] = b
        return out


def d2_file_offset(addr):
    """Offset in the DROID2 file of the byte the listing shows at run
    address ``addr`` (blocks are stored in D2_BLOCKS order)."""
    off = 0
    for first, last, _ in D2_BLOCKS:
        if first <= addr <= last:
            return off + addr - first
        off += last - first + 1
    raise KeyError(hex(addr))
