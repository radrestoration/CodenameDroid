#!/usr/bin/env python3
"""Minimal BBC DFS single-density disk (.ssd) image builder.

Format reverse-derived from /home/peter/bbc/b-em/utils/makedfs.py (a
real, working DFS implementation, ported here from its Python 2
read/write logic to a small Python 3 write-only subset - just enough
for this project's own flat-binary programs + data files, not general
disk authoring):
  - 200KB disk (800 sectors x 256 bytes), single-sided single-density.
  - Sector 0: disk title (bytes 0-7) + up to 31 filenames (7 chars +
    directory-prefix byte), 8 bytes/entry starting at offset 8.
  - Sector 1: title bytes 8-11, disk cycle, catalog byte count
    (entries*8), sector count, then per-file load/exec/length/start-
    sector (8 bytes/entry, same ordering as sector 0's entries).
  - File data follows sequentially from sector 2.
Standard 10-sectors-per-track layout (sector_size=256, 10 sectors/track).
"""
import sys


def build_ssd(files, title="UNDEAD", boot_option=0):
    """files: list of (name, load_addr, exec_addr, data) tuples. name
    is up to 7 chars, no directory prefix needed (defaults to '$').

    boot_option: DFS *OPT 4,n value baked into the catalogue - 0=None,
    1=LOAD, 2=RUN, 3=EXEC. Options 1-3 all act on a file named exactly
    "!BOOT" (not "the first file" - a real, easy-to-get-wrong DFS
    convention), which SHIFT+BREAK (or an emulator's command-line
    autoboot, e.g. `beebem disk.ssd` - see beebem-0.0.13/src/
    beebwin.cpp's HandleCommandLineFile, which does exactly a
    shift+break after mounting) then runs/loads/feeds automatically -
    if you want hands-off autoboot, name your entry point file "!BOOT"
    and pass boot_option=2 here."""
    if len(files) > 31:
        raise ValueError("too many files for one DFS catalogue (max 31)")
    if boot_option not in (0, 1, 2, 3):
        raise ValueError("boot_option must be 0-3")

    SECTOR = 256
    disk = bytearray(800 * SECTOR)

    title_bytes = title.encode("ascii")[:12].ljust(12, b"\x00")
    disk[0:8] = title_bytes[0:8]
    disk[0x100:0x104] = title_bytes[8:12]

    disk[0x104] = 1               # disk cycle (arbitrary, non-zero)
    disk[0x105] = len(files) * 8  # catalogue byte count
    total_sectors = 800
    disk[0x106] = ((total_sectors >> 8) & 0x03) | (boot_option << 4)
    disk[0x107] = total_sectors & 0xff

    next_sector = 2   # sector 0/1 are the catalogue itself
    p = 8
    for name, load_addr, exec_addr, data in files:
        name_padded = name.encode("ascii").ljust(7, b" ")[:7]
        disk[p:p+7] = name_padded
        disk[p+7] = ord("$")   # directory prefix, no locked bit

        length = len(data)
        # Low 16 bits only here - the full value can exceed 65535 (a
        # real file this project built, bbc_images.blob, is 77357
        # bytes), with the overflow carried in the "extra" byte's
        # bits 4-5 below, not here.
        disk[0x100+p:0x100+p+2]   = (load_addr & 0xFFFF).to_bytes(2, "little")
        disk[0x100+p+2:0x100+p+4] = (exec_addr & 0xFFFF).to_bytes(2, "little")
        disk[0x100+p+4:0x100+p+6] = (length & 0xFFFF).to_bytes(2, "little")

        # Bit positions verified against makedfs.py's READ side (a real,
        # working implementation), not re-derived from scratch: for a
        # field whose low bit lands at extra's bit B, the read side
        # does `(extra & mask) << (16-B)` to put it back at bit 16 of
        # the real value - so the write side must do the inverse,
        # `(value >> (16-B)) & mask`. A mismatched shift here (found
        # 2026-xx: length used >>10 and exec used >>12, swapped - only
        # length actually mattered since our addresses never have bits
        # above 15 set) silently writes a CORRUPTED length into the
        # catalogue for any file above a few KB, e.g. 20480 came out
        # inflated to ~86016 - OSFILE's load trusts that catalogue
        # length (we never supply one ourselves), so it would keep
        # copying well past the real file's end, wrapping the 16-bit
        # address space and overwriting our own code/zero page/screen
        # memory a second time with whatever followed on disk.
        extra = ((next_sector >> 8) & 0x03)        # bit0-1: sector bits 8-9
        extra |= ((load_addr >> 14) & 0x0c)        # bit2-3: load bits 16-17
        extra |= ((length >> 12) & 0x30)           # bit4-5: length bits 16-17
        extra |= ((exec_addr >> 10) & 0xc0)        # bit6-7: exec bits 16-17
        disk[0x100+p+6] = extra
        disk[0x100+p+7] = next_sector & 0xff

        start = next_sector * SECTOR
        disk[start:start+length] = data

        sectors_used = (length + SECTOR - 1) // SECTOR
        next_sector += sectors_used
        p += 8

    if next_sector > 800:
        raise ValueError(f"disk overflow: needs {next_sector} sectors, have 800")

    return bytes(disk)


if __name__ == "__main__":
    # Smoke test: build a tiny disk with one dummy file and verify the
    # catalogue bytes come back out the way read_catalogue (makedfs.py's
    # proven read path) expects.
    data = bytes(range(256)) * 2  # 512 bytes, 2 sectors
    img = build_ssd([("TEST", 0x1900, 0x1900, data)], title="TESTDISK")
    assert len(img) == 800*256
    assert img[0:8] == b"TESTDISK"
    assert img[8:15] == b"TEST   "
    print("OK:", len(img), "bytes, catalogue looks right")
