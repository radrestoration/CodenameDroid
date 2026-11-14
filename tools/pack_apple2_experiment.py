#!/usr/bin/env python3
"""Wrap a raw Apple II binary in LinApple's load-and-run APL format."""
import struct
import sys
from pathlib import Path

data = Path(sys.argv[1]).read_bytes()
if not data or len(data) > 0x8000:
    raise ValueError("Apple II experiment must fit at $4000-$bfff")
Path(sys.argv[2]).write_bytes(struct.pack("<HH", 0x4000, len(data)) + data)
