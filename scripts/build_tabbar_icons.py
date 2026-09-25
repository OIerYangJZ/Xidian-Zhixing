#!/usr/bin/env python3
"""Builds the mini program tab bar icons from the design handoff.

Source: docs/design/项目UI设计总纲/icons/tabbar/<theme>/<name>[-active].png
(81 × 81, one colour each). Output: miniprogram/assets/tabbar/<theme>/ as-is
and <theme>_dark/ recoloured for dark mode, which the handoff does not draw.

The handoff PNGs carry C2PA provenance in a caBX chunk; the light copies
keep every other chunk byte for byte and drop that one. Dark copies are
re-encoded from the alpha mask, so they carry nothing extra either.

    python3 scripts/build_tabbar_icons.py
"""
from __future__ import annotations

import shutil
import struct
import zlib
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs/design/项目UI设计总纲/icons/tabbar"
TARGET = ROOT / "miniprogram/assets/tabbar"
NAMES = ("treehole", "campus", "ai", "message", "mine")

# Dark-mode text-3 (idle) and primary (selected), from
# flutter_app/lib/design_system/zx_palette.g.dart.
DARK = {
    "zhushachi": ("9F9D96", "E08075"),
    "zhuqing": ("9CA19B", "91C29C"),
    "xingrenhuang": ("A29D92", "E1B665"),
    "mozhuxinye": ("9F9F9B", "E37D73"),
}


def strip_c2pa(data: bytes) -> bytes:
    """The PNG with its caBX (C2PA) chunks removed, all else unchanged."""
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG"
    out = bytearray(data[:8])
    i = 8
    while i < len(data):
        length = struct.unpack(">I", data[i : i + 4])[0]
        kind = data[i + 4 : i + 8]
        end = i + 12 + length
        chunk = data[i:end]
        crc = struct.unpack(">I", chunk[-4:])[0]
        assert zlib.crc32(chunk[4:-4]) & 0xFFFFFFFF == crc, f"bad CRC in {kind!r}"
        if kind != b"caBX":
            out += chunk
        i = end
    return bytes(out)


def recolour(path: Path, hex_colour: str, dest: Path) -> None:
    alpha = Image.open(path).convert("RGBA").getchannel("A")
    rgb = tuple(int(hex_colour[k : k + 2], 16) for k in (0, 2, 4))
    image = Image.new("RGBA", alpha.size, rgb + (0,))
    image.putalpha(alpha)
    image.save(dest, optimize=True)


def main() -> None:
    if TARGET.exists():
        shutil.rmtree(TARGET)
    for theme, (idle, selected) in DARK.items():
        light_dir = TARGET / theme
        dark_dir = TARGET / f"{theme}_dark"
        light_dir.mkdir(parents=True)
        dark_dir.mkdir(parents=True)
        for name in NAMES:
            for suffix, dark_colour in (("", idle), ("-active", selected)):
                source = SOURCE / theme / f"{name}{suffix}.png"
                cleaned = strip_c2pa(source.read_bytes())
                assert b"caBX" not in cleaned and b"c2pa" not in cleaned
                (light_dir / source.name).write_bytes(cleaned)
                recolour(source, dark_colour, dark_dir / source.name)
    print(f"wrote {len(list(TARGET.rglob('*.png')))} icons to {TARGET}")


if __name__ == "__main__":
    main()
