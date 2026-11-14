#!/usr/bin/env python3
"""Pack the 512-byte boot block into an 800 KB ProDOS-order 3.5" image (1600 blocks of 512 bytes).
Only block 0 is filled; no ProDOS volume directory yet."""
import sys
boot = open(sys.argv[1], "rb").read()
assert len(boot) == 512 and boot[0] == 1, "boot block must be 512 bytes starting with $01"
open(sys.argv[2], "wb").write(boot + bytes(512 * 1599))
