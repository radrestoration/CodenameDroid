"""Assemble a 65816 snippet with the project's ca65/ld65 to raw bytes at a given origin (for the tests)."""
import os
import subprocess
import tempfile
from pathlib import Path


def cc65_bin():
    cfg = Path(__file__).resolve().parent.parent / "tools.cfg"
    home = None
    if cfg.exists():
        for line in cfg.read_text().splitlines():
            if line.startswith("CC65_HOME="):
                home = os.path.expanduser(line.split("=", 1)[1].strip())
    return Path(home) / "bin" if home else Path("")


def assemble(source, origin=0x0800, size=0x1000):
    """Return the bytes of `source` (a ca65 source without .p816/.segment lines) assembled at `origin`."""
    b = cc65_bin()
    with tempfile.TemporaryDirectory() as t:
        t = Path(t)
        (t / "a.s").write_text('.p816\n.smart +\n.segment "CODE"\n' + source)
        (t / "a.cfg").write_text(
            f'MEMORY {{ M: file = "%O", start = ${origin:04x}, size = ${size:04x}; }}\n'
            'SEGMENTS { CODE: load = M, type = ro; }\n')
        subprocess.run([str(b / "ca65"), str(t / "a.s"), "-o", str(t / "a.o")], check=True)
        subprocess.run([str(b / "ld65"), "-C", str(t / "a.cfg"), str(t / "a.o"), "-o", str(t / "a.bin")],
                       check=True)
        return (t / "a.bin").read_bytes()
