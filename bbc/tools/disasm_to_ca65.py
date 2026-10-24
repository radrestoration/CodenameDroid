#!/usr/bin/env python3
"""One-off conversion of codename-droid-disassembly.txt to ca65 source.

    tools/disasm_to_ca65.py codename-droid-disassembly.txt src/

writes src/symbols.inc, src/droid.s (the DROID file) and src/droid2.s
(the DROID2 file). After that the files in src/ ARE the source; the
listing is not read again by the build (check_build.py compares the
result against it). Running this again overwrites src/ - `make regen`.

What the conversion does, and what it does not do:
  - every instruction keeps its listing mnemonic and operand value; the
    operand is written as a label where the address is a label in the
    listing (or the target of a branch/JSR/JMP, which gets one), as a
    named constant where the listing annotates the operand with a clean
    identifier ("STA &5f ; player_x"), else as the number;
  - labels that appear more than once in the listing (skip_wraparound,
    leave, ...) get their address appended, since ca65 labels are global
    here;
  - data lines stay .byte lines with the listing's comment;
  - nothing is re-interpreted: all of it is checked by assembling and
    comparing against the listing's own bytes.
"""
import collections
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from droidlist import (BRANCHES, D2_BLOCKS, LABEL_ADDRESS_FIXES, Listing)  # noqa: E402

CLEAN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
RESERVED = {"a", "x", "y", "z", "s", "A", "X", "Y", "Z", "S"}
CMT_COL = 36


def operand_info(it):
    """-> (kind, value, width): kind in imm/zp/zpx/zpy/indx/indy/abs/
    absx/absy/ind/rel/acc/none; width = hex digits in the listing."""
    op, m = it.opstr, None
    if it.mnem in BRANCHES:
        return "rel", int(op[1:], 16), 4
    if op == "":
        return "none", None, 0
    if op == "A":
        return "acc", None, 0
    if op.startswith("#&"):
        return "imm", int(op[2:], 16), 2
    for rx, kind in ((r"^\(&([0-9a-f]{2}),X\)$", "indx"),
                     (r"^\(&([0-9a-f]{2})\),Y$", "indy"),
                     (r"^\(&([0-9a-f]{4})\)$", "ind"),
                     (r"^&([0-9a-f]{2}),X$", "zpx"),
                     (r"^&([0-9a-f]{2}),Y$", "zpy"),
                     (r"^&([0-9a-f]{4}),X$", "absx"),
                     (r"^&([0-9a-f]{4}),Y$", "absy"),
                     (r"^&([0-9a-f]{2})$", "zp"),
                     (r"^&([0-9a-f]{4})$", "abs")):
        m = re.match(rx, op)
        if m:
            return kind, int(m.group(1), 16), len(m.group(1))
    raise ValueError("line %d: operand %r" % (it.lineno, op))


def line_with_comment(code, cmt):
    if not cmt:
        return code.rstrip()
    return code.ljust(CMT_COL) + " ; " + cmt


def block_of(addr):
    for first, last, name in D2_BLOCKS:
        if first <= addr <= last:
            return name
    raise KeyError(hex(addr))


def main(listing_path, outdir):
    L = Listing(listing_path)

    # ---- 1. which address does each label name? --------------------
    pending = []
    label_at = collections.defaultdict(list)     # (space, addr) -> [(name, cmt)]
    name_count = collections.Counter()
    # D1's loader page (&5800-&58ff) and D2's tile data share addresses:
    # keep them apart as "spaces"
    def space_of(it):
        return "D1" if it.sec == "DROID" else "D2"
    for ent in L.stream:
        if ent[0] == "label":
            pending.append(ent)
            name_count[ent[1]] += 1
        elif ent[0] == "item":
            it = ent[1]
            for _, name, cmt, ln in pending:
                a = LABEL_ADDRESS_FIXES.get(name, it.addr)
                label_at[(space_of(it), a)].append((name, cmt))
            pending = []
        elif ent[0] == "section" and pending:
            raise SystemExit("label before section header: %r" % pending)
    assert not pending

    def final_name(name, addr):
        return name if name_count[name] == 1 else "%s_%04x" % (name, addr)

    # ---- 2. operand kinds; synthesize labels for jump targets ------
    spans = {"D1": [(i.addr, i.end) for i in L.items if i.sec == "DROID"],
             "D2": [(i.addr, i.end) for i in L.items if i.sec == "DROID2"]}
    def in_space(space, a):
        return any(lo <= a < hi for lo, hi in spans[space])

    def resolve_space(it, addr):
        """Which space does a reference from ``it`` to ``addr`` mean?
        D1's game code (below &5800) reaching &5800+ means D2's tiles;
        D1's loader page and everything in D2 refer to their own."""
        if it.sec == "DROID2":
            return "D2" if in_space("D2", addr) else ("D1" if in_space("D1", addr) else None)
        if it.addr >= 0x5800:                       # the loader
            return "D1" if in_space("D1", addr) else None
        if addr >= 0x5800 and in_space("D2", addr):
            return "D2"
        return "D1" if in_space("D1", addr) else ("D2" if in_space("D2", addr) else None)

    synth = {}                                      # (space, addr) -> name
    for it in L.items:
        if not it.is_code:
            continue
        kind, val, w = operand_info(it)
        if kind == "rel" or it.mnem in ("JSR", "JMP"):
            sp = resolve_space(it, val)
            if sp and (sp, val) not in label_at and (sp, val) not in synth:
                synth[(sp, val)] = "L_%04x" % val if sp == "D1" else "L2_%04x" % val
    for key, nm in synth.items():
        label_at[key].append((nm, ""))
        name_count[nm] += 1

    def name_for(space, addr, prefer=None):
        cands = [n for n, _ in label_at[(space, addr)]]
        if prefer in cands:
            return final_name(prefer, addr)
        return final_name(cands[0], addr)

    # ---- 3. named constants from operand annotations ---------------
    names_of = collections.defaultdict(set)         # name -> {addresses}
    all_labels = {n for v in label_at.values() for n, _ in v}
    for it in L.items:
        if not it.is_code or not CLEAN.match(it.ann.split("  ")[0] if it.ann else ""):
            continue
        kind, val, w = operand_info(it)
        if kind in ("imm", "none", "acc"):
            continue
        sp = resolve_space(it, val) if kind in ("abs", "absx", "absy", "rel", "ind") else None
        if kind != "rel" and not (sp and (sp, val) in label_at):
            names_of[it.ann.split("  ")[0]].add(val)
    equates = {}                                    # name -> address
    ambiguous = []
    for nm, addrs in names_of.items():
        if nm in RESERVED or nm in all_labels or len(addrs) != 1:
            if nm not in all_labels and nm not in RESERVED:
                ambiguous.append((nm, sorted(addrs)))
            continue
        equates[nm] = next(iter(addrs))
    # an external JSR/JMP/indirect target with no usable name
    ext = {}
    for it in L.items:
        if it.is_code and it.mnem in ("JSR", "JMP"):
            kind, val, w = operand_info(it)
            if resolve_space(it, val) is None and val not in equates.values():
                ext[val] = "ext_%04x" % val
    for val, nm in ext.items():
        equates[nm] = val
    addr_name = {}
    for nm, a in equates.items():
        addr_name.setdefault(a, []).append(nm)

    # ---- 4. emit ----------------------------------------------------
    def fmt_val(v, w):
        return "$%0*x" % (w, v)

    def operand_text(it):
        kind, val, w = operand_info(it)
        ann = it.ann.split("  ")[0] if it.ann else ""
        sym = None
        if kind in ("imm", "none", "acc"):
            pass
        elif kind == "rel" or it.mnem in ("JSR", "JMP"):
            sp = resolve_space(it, val)
            if sp:
                sym = name_for(sp, val, ann)
            else:
                sym = ann if equates.get(ann) == val else addr_name[val][0]
        else:
            sp = resolve_space(it, val) if w == 4 else None
            if sp and (sp, val) in label_at:
                sym = name_for(sp, val, ann)
            elif ann in equates and equates[ann] == val:
                sym = ann
        if kind == "none":
            return "", sym
        if kind == "acc":
            return "a", sym
        if kind == "rel":
            return sym, sym
        if kind == "imm":
            return "#" + fmt_val(val, 2), sym
        txt = sym if sym else fmt_val(val, w)
        # an absolute-mode operand below &100 needs forcing, or ca65
        # would assemble the zero-page form
        if w == 4 and val < 0x100 and kind in ("abs", "absx", "absy"):
            txt = "a:" + txt
        if kind in ("indx",):
            return "(%s,x)" % txt, sym
        if kind in ("indy",):
            return "(%s),y" % txt, sym
        if kind == "ind":
            return "(%s)" % txt, sym
        if kind in ("zpx", "absx"):
            return txt + ",x", sym
        if kind in ("zpy", "absy"):
            return txt + ",y", sym
        return txt, sym

    def comment_text(it, sym, extra=""):
        parts = []
        base = re.sub(r"_[0-9a-f]{4}$", "", sym) if sym else None
        if it.ann and not (sym and it.ann.split("  ")[0] in (sym, base)):
            parts.append(it.ann)
        elif it.ann and "  " in it.ann:
            parts.append(it.ann.split("  ", 1)[1])
        if it.cmt:
            parts.append(("# " if parts else "") + it.cmt)
        if extra:
            parts.append(extra)
        return "  ".join(parts)

    out = {"DROID": [], "DROID2": []}
    cur_sec = None
    cur_seg = {"DROID": None, "DROID2": None}

    def seg_switch(sec, seg):
        if cur_seg[sec] != seg:
            out[sec].append("")
            out[sec].append('.segment "%s"' % seg)
            out[sec].append("")
            cur_seg[sec] = seg

    pending_labels = []
    for ent in L.stream:
        k = ent[0]
        if k == "section":
            cur_sec = ent[1]
            continue
        if cur_sec is None:
            continue
        o = out[cur_sec]
        if k == "fileheader":
            o.append("; load/exec/length: " + ent[1])
        elif k == "blank":
            o.append("")
        elif k == "comment":
            t = ent[1]
            o.append(";" + t[1:] if t.startswith("#") else t)
        elif k == "label":
            pending_labels.append(ent)
        elif k == "item":
            it = ent[1]
            sp = space_of(it)
            if cur_sec == "DROID":
                seg_switch("DROID", "DROID")
            else:
                seg_switch("DROID2", block_of(it.addr))
            # labels: the listed ones, then any synthesized ones for this address
            listed = {n for _, n, _, _ in pending_labels}
            for _, nm, cmt, ln in pending_labels:
                if LABEL_ADDRESS_FIXES.get(nm, it.addr) != it.addr:
                    continue                # emitted inside the data item
                o.append(line_with_comment(final_name(nm, it.addr) + ":",
                                           ("# " + cmt) if cmt else ""))
            pending_labels = []
            for nm, _ in label_at[(sp, it.addr)]:
                if nm not in listed and nm.startswith(("L_", "L2_")):
                    o.append(nm + ":")
            if it.is_code:
                # a label in the middle of an instruction would need an
                # offset expression; there are none, so make that loud
                for a in range(it.addr + 1, it.end):
                    if (sp, a) in label_at:
                        raise SystemExit("label inside instruction at %04x line %d"
                                         % (a, it.lineno))
                txt, sym = operand_text(it)
                code = "    " + it.mnem.lower() + ((" " + txt) if txt else "")
                o.append(line_with_comment(code, comment_text(it, sym)))
            else:
                emit_data(o, it, label_at, sp, final_name)

    # ---- 5. write ---------------------------------------------------
    os.makedirs(outdir, exist_ok=True)
    hdr = open(listing_path, encoding="utf-8").read().split("\n")[:36]
    banner = ["; " + h if h else ";" for h in hdr[2:16]]

    with open(os.path.join(outdir, "symbols.inc"), "w") as f:
        f.write("; Named addresses taken from the operand annotations in the listing\n"
                "; (\"STA &5f ; enemy_energy_and_initial_flags\"), and the OS entry points\n"
                "; it calls. Generated by tools/disasm_to_ca65.py, then maintained by hand.\n\n")
        for nm, a in sorted(equates.items(), key=lambda kv: (kv[1], kv[0])):
            f.write("%-44s = $%0*x\n" % (nm, 2 if a < 0x100 else 4, a))
    for sec, fname, title in (("DROID", "droid.s", "DROID: the game (load &1100, exec &5800 = the loader at the end)"),
                              ("DROID2", "droid2.s", "DROID2: data and entry code (load &6500, exec &7b00)")):
        with open(os.path.join(outdir, fname), "w") as f:
            f.write("; Codename Droid (BBC Micro, Superior Software 1987) - %s\n;\n" % title)
            f.write("; Converted from codename-droid-disassembly.txt by tools/disasm_to_ca65.py.\n"
                    "; The preamble of that disassembly:\n;\n")
            f.write("\n".join(banner) + "\n\n")
            f.write("\n".join(out[sec]).strip("\n") + "\n")
    with open(os.path.join(outdir, "main.s"), "w") as f:
        f.write('; Codename Droid - one assembly unit; droid.cfg places the two files.\n\n'
                '.include "symbols.inc"\n.include "droid.s"\n.include "droid2.s"\n')
    sys.stderr.write("labels %d (synthesized %d), constants %d, ambiguous names %d\n"
                     % (len(all_labels), len(synth), len(equates), len(ambiguous)))
    for nm, a in ambiguous[:40]:
        sys.stderr.write("  ambiguous: %s %s\n" % (nm, ["%04x" % x for x in a]))


def emit_data(o, it, label_at, sp, final_name):
    """.byte lines for a data item, split where a label sits inside it."""
    cuts = [it.addr] + [a for a in range(it.addr + 1, it.end) if (sp, a) in label_at] + [it.end]
    cmt = ("; " + it.ann if it.ann else "") + (("  # " + it.cmt) if it.cmt else "")
    for ci in range(len(cuts) - 1):
        lo, hi = cuts[ci], cuts[ci + 1]
        if ci:
            for nm, c in label_at[(sp, lo)]:
                o.append(final_name(nm, lo) + ":")
        chunk = it.data[lo - it.addr:hi - it.addr]
        s = re.match(r'^"([^"]*)"$', it.ann.strip())
        if s and chunk == s.group(1).encode("latin1") and ci == 0 and len(cuts) == 2:
            code = '    .byte "%s"' % s.group(1)
        else:
            code = "    .byte " + ",".join("$%02x" % b for b in chunk)
        o.append(line_with_comment(code, cmt if ci == 0 else ""))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
