#!/usr/bin/env python3
"""Build the Songti fonts the app bundles from the full STZhongsong / STSong.

Flutter Web downloads every font in the manifest before it draws the first
frame, so the two full Songti files (22.6 MB and 20.7 MB) held back the whole
app. They are split along ZxSans's character set (scripts/build_web_font.py):

  * STZhongsong-Subset.ttf: the display face for exactly the characters ZxSans
    covers (GB 2312 plus every UI character). Bundled as the STZhongsong font.
  * STSong-Rare.ttf: STSong for everything ZxSans lacks, i.e. rare hanzi in
    names and user content. Not in the font manifest; web loads it after the
    first frame (ZxFonts.loadDeferred).

The full sources stay in flutter_app/assets/fonts but are not bundled.

Usage (needs fonttools): python3 scripts/build_songti_fonts.py
Rerun after build_web_font.py changes ZxSans.
"""

from __future__ import annotations

import io
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

FONTS = Path(__file__).resolve().parents[1] / "flutter_app" / "assets" / "fonts"
WEB_FONTS = Path(__file__).resolve().parents[1] / "flutter_app" / "web" / "fonts"


def _subset(source: str, unicodes: set[int], output: Path) -> None:
    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.notdef_outline = True
    options.hinting = False  # CanvasKit does not use TrueType hinting.
    font = TTFont(FONTS / source)
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=unicodes)
    subsetter.subset(font)
    buffer = io.BytesIO()
    font.save(buffer)
    output.write_bytes(buffer.getvalue())
    print(f"{output.name}: {len(buffer.getvalue()) / 1024 / 1024:.2f} MB, {len(unicodes)} characters")


def main() -> None:
    body = set(TTFont(FONTS / "ZxSans-Regular.ttf").getBestCmap())
    display = set(TTFont(FONTS / "STZhongsong.ttf").getBestCmap())
    song = set(TTFont(FONTS / "STSong.ttf").getBestCmap())
    _subset("STZhongsong.ttf", display & body, FONTS / "STZhongsong-Subset.ttf")
    # Web only, fetched after the first frame; outside the asset bundle so
    # the APK does not carry it.
    _subset("STSong.ttf", song - body, WEB_FONTS / "STSong-Rare.ttf")


if __name__ == "__main__":
    main()
