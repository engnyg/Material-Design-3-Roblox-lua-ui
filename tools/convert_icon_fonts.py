#!/usr/bin/env python3
"""Download Google's Material Icons style fonts and convert them to TTF.

Google ships the Outlined / Round / Sharp styles only as .otf (CFF outlines).
Roblox custom fonts are known to work with TrueType, so this converts the
cubic CFF outlines to quadratic glyf outlines (fontTools cu2qu) and writes
assets/fonts/MaterialIcons<Style>-Regular.ttf, which IconFont.lua downloads.
The Filled style is already a .ttf and is loaded straight from Google.

Fonts: https://github.com/google/material-design-icons (Apache-2.0)

Usage: pip install fonttools && python3 tools/convert_icon_fonts.py
"""
import io
import urllib.request
from pathlib import Path

from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont, newTable

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "fonts"
SOURCE = "https://raw.githubusercontent.com/google/material-design-icons/master/font/MaterialIcons{}-Regular.otf"
STYLES = ["Outlined", "Round", "Sharp"]

# Max deviation (font units; Material Icons use 512 units/em) allowed
# when approximating cubic curves with quadratics.
MAX_ERR = 0.5


def otf_to_ttf(font: TTFont) -> None:
    """In-place CFF -> glyf conversion (adapted from fontTools' otf2ttf snippet)."""
    glyph_order = font.getGlyphOrder()
    font["loca"] = newTable("loca")
    font["glyf"] = glyf = newTable("glyf")
    glyf.glyphOrder = glyph_order
    glyf.glyphs = {}
    glyph_set = font.getGlyphSet()
    for name in glyph_order:
        tt_pen = TTGlyphPen(glyph_set)
        glyph_set[name].draw(Cu2QuPen(tt_pen, MAX_ERR, reverse_direction=True))
        glyf[name] = tt_pen.glyph()

    del font["CFF "]
    if "VORG" in font:
        del font["VORG"]
    glyf.compile(font)

    # TrueType renderers place glyphs using hmtx's left side bearing, which
    # must equal each glyph's xMin. CFF doesn't rely on it (these fonts
    # store 0), so without this every icon renders shifted to the left.
    hmtx = font["hmtx"]
    for name in glyph_order:
        glyph = glyf[name]
        advance, _ = hmtx[name]
        glyph.recalcBounds(glyf)
        hmtx[name] = (advance, getattr(glyph, "xMin", 0))

    maxp = font["maxp"] = newTable("maxp")
    maxp.tableVersion = 0x00010000
    maxp.maxZones = 1
    maxp.maxTwilightPoints = 0
    maxp.maxStorage = 0
    maxp.maxFunctionDefs = 0
    maxp.maxInstructionDefs = 0
    maxp.maxStackElements = 0
    maxp.maxSizeOfInstructions = 0
    maxp.maxComponentElements = max(
        (len(g.components) for g in glyf.glyphs.values() if g.isComposite()), default=0
    )
    maxp.compile(font)

    post = font["post"]
    post.formatType = 2.0
    post.extraNames = []
    post.mapping = {}
    post.glyphOrder = glyph_order

    font.sfntVersion = "\x00\x01\x00\x00"


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for style in STYLES:
        url = SOURCE.format(style)
        with urllib.request.urlopen(url) as response:
            data = response.read()
        font = TTFont(io.BytesIO(data))
        otf_to_ttf(font)
        path = OUT / f"MaterialIcons{style}-Regular.ttf"
        font.save(path)
        print(f"wrote {path.relative_to(ROOT)} ({path.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
