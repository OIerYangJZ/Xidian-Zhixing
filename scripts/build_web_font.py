#!/usr/bin/env python3
"""Build the bundled web body font (ZxSans) from Noto Sans SC.

Flutter Web draws with CanvasKit and cannot use the visitor's system fonts,
and production cannot fetch Google's fallback fonts, so the body sans has to
ship with the app. The full font is 17 MB; this keeps two static weights
(400, 600) of the characters the app actually needs:

  * GB 2312 (the 6763 common hanzi plus its punctuation and symbols),
  * printable ASCII and common CJK punctuation,
  * every character in the UI sources (Dart, l10n, mini program), so no UI
    string can fall outside the subset.

Anything rarer in user content falls back to the bundled STSong (see
ZxFonts.bodyFallback), never to a download.

Usage (needs fonttools; the source font is not kept in the repo):

  curl -L -o /tmp/NotoSansSC.ttf \\
    "https://github.com/google/fonts/raw/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf"
  python3 scripts/build_web_font.py /tmp/NotoSansSC.ttf

Rerun when new UI text adds characters; the output is deterministic for a
given source font and character set.
Then rerun scripts/build_songti_fonts.py, which splits the Songti fonts along
ZxSans's character set.
"""

from __future__ import annotations

import io
import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "flutter_app" / "assets" / "fonts"
WEIGHTS = {400: "ZxSans-Regular.ttf", 600: "ZxSans-SemiBold.ttf"}
UI_SOURCES = [
    (ROOT / "flutter_app" / "lib", ("*.dart", "*.arb")),
    (ROOT / "miniprogram", ("*.js", "*.wxml", "*.json")),
]


def gb2312_characters() -> set[str]:
    chars: set[str] = set()
    for high in range(0xA1, 0xF8):
        for low in range(0xA1, 0xFF):
            try:
                chars.add(bytes([high, low]).decode("gb2312"))
            except UnicodeDecodeError:
                pass
    return chars


def ui_characters() -> set[str]:
    chars: set[str] = set()
    for base, patterns in UI_SOURCES:
        for pattern in patterns:
            for path in base.rglob(pattern):
                if "node_modules" in path.parts or path.name.endswith(".g.dart"):
                    continue
                chars.update(path.read_text(encoding="utf-8", errors="ignore"))
    # Only characters a text font should carry.
    return {c for c in chars if ord(c) >= 0x20 and not 0xD800 <= ord(c) <= 0xDFFF}


def character_set() -> set[str]:
    chars = gb2312_characters() | ui_characters()
    chars.update(chr(c) for c in range(0x20, 0x7F))
    chars.update("，。、；：？！“”‘’（）《》〈〉【】「」『』…—～·￥")
    return chars


def build(source: Path) -> None:
    text = "".join(sorted(character_set()))
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for weight, name in WEIGHTS.items():
        font = instancer.instantiateVariableFont(TTFont(source), {"wght": weight})
        options = subset.Options()
        options.layout_features = ["*"]
        options.name_IDs = ["*"]
        options.notdef_outline = True
        options.hinting = False  # CanvasKit does not use TrueType hinting.
        subsetter = subset.Subsetter(options)
        subsetter.populate(text=text)
        subsetter.subset(font)
        buffer = io.BytesIO()
        font.save(buffer)
        (OUT_DIR / name).write_bytes(buffer.getvalue())
        print(f"{name}: {len(buffer.getvalue()) / 1024 / 1024:.2f} MB, {len(text)} characters")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    build(Path(sys.argv[1]))
