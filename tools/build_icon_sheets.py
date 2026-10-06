#!/usr/bin/env python3
"""Render Google's whole Material icon set into paged PNG sprite sheets.

Executors reliably load external *images* through getcustomasset (the same
way NeverLose loads its logo), while custom *fonts* built from getcustomasset
files don't work everywhere. So the icons ship as images too: each style is a
set of pages, each a grid of white glyphs on transparency (tinted at runtime
via ImageColor3).

Icons come from google/material-design-icons (Apache-2.0):
  * every Material Icons name, drawn from that style's Material Icons font
    (the same fonts IconFont.lua loads, so names, codepoints and filled /
    outlined variants match the font path), and
  * every Material Symbols name the Material Icons fonts don't have, drawn
    from the Material Symbols variable fonts (Outlined style unfilled, the
    other styles filled, like their Material Icons counterparts).

Page 0 starts with CORE, the icons the library itself draws, so a window
only downloads one page up front; the others load the first time one of
their icons is shown.

Outputs:
  assets/icons/<Style>/<page>.png   the pages of each style
  src/Core/IconSheet.lua            sheet geometry, name -> cell, codepoints

Usage: pip install fonttools pillow && python3 tools/build_icon_sheets.py
       (downloads ~35 MB of Material Symbols fonts from GitHub)
"""
import io
import math
import shutil
import urllib.request
from pathlib import Path

from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SHEET_LUA = ROOT / "src" / "Core" / "IconSheet.lua"
OUT = ROOT / "assets" / "icons"
FONTS = ROOT / "assets" / "fonts"

VERSION = 2  # bump when the layout changes: clients cache pages by this
CELL = 64  # px per icon; icons are drawn 24-48px in the UI, so this stays crisp
GUTTER = 4  # transparent margin around each cell so neighbours never bleed in
PITCH = CELL + 2 * GUTTER
COLUMNS = 14  # 14 x 72 = 1008 px, under Roblox's 1024 px image limit
ROWS = 14
PER_PAGE = COLUMNS * ROWS

GOOGLE = "https://raw.githubusercontent.com/google/material-design-icons/master/"
LEGACY_CODEPOINTS = GOOGLE + "font/MaterialIcons-Regular.codepoints"
SYMBOLS = GOOGLE + "variablefont/MaterialSymbols{}%5BFILL,GRAD,opsz,wght%5D"

# style -> (Material Icons font, (Material Symbols family, FILL))
STYLES = {
    "Outlined": (FONTS / "MaterialIconsOutlined-Regular.ttf", ("Outlined", 0)),
    "Filled": (GOOGLE + "font/MaterialIcons-Regular.ttf", ("Outlined", 1)),
    "Round": (FONTS / "MaterialIconsRound-Regular.ttf", ("Rounded", 1)),
    "Sharp": (FONTS / "MaterialIconsSharp-Regular.ttf", ("Sharp", 1)),
}

# Names this library has always accepted that Google's lists don't have.
ALIASES = {"brightness_dark": "brightness_4", "brightness_light": "brightness_7"}

# The icons the library draws itself (and the original 139), kept on page 0.
CORE = [
    "add", "alarm", "arrow_back", "arrow_drop_down", "arrow_drop_up", "arrow_forward",
    "attach_file", "auto_awesome", "autorenew", "backpack", "bar_chart", "block", "bolt",
    "bookmark", "bookmark_border", "brightness_dark", "brightness_light", "build",
    "calendar_today", "camera_alt", "cancel", "chat", "check", "check_box",
    "check_box_outline_blank", "check_circle", "chevron_left", "chevron_right", "close",
    "close_fullscreen", "cloud", "code", "colorize", "comment", "content_copy", "credit_card",
    "dark_mode", "dashboard", "delete", "done", "download", "drag_handle", "drag_indicator",
    "edit", "error", "event", "expand_less", "expand_more", "explore", "fast_forward",
    "fast_rewind", "favorite", "filter_list", "flag", "folder", "fullscreen", "fullscreen_exit",
    "grid_view", "group", "groups", "help_outline", "history", "home", "image", "info", "keyboard",
    "keyboard_arrow_down", "keyboard_arrow_left", "keyboard_arrow_right", "keyboard_arrow_up",
    "language", "light_mode", "link", "list", "location_on", "lock", "lock_open", "login",
    "logout", "mail", "menu", "mic", "mic_off", "minimize", "more_horiz", "more_vert",
    "notifications", "open_in_full", "open_in_new", "palette", "pause", "person", "play_arrow",
    "priority_high", "public", "radio_button_checked", "radio_button_unchecked", "refresh",
    "remove", "reorder", "report", "save", "schedule", "search", "send", "settings", "share",
    "shield", "shopping_cart", "skip_next", "skip_previous", "sort", "speed", "sports_esports",
    "star", "stop", "swap_horiz", "swap_vert", "sync", "tag", "terminal", "thumb_down", "thumb_up",
    "timer", "toggle_off", "toggle_on", "touch_app", "tune", "upload", "verified", "visibility",
    "visibility_off", "volume_off", "volume_up", "warning", "widgets", "wifi", "zoom_in",
    "zoom_out",
]


def fetch(url: str) -> bytes:
    with urllib.request.urlopen(url) as response:
        return response.read()


def parse_codepoints(text: str) -> dict:
    out = {}
    for line in text.splitlines():
        if line.strip():
            name, codepoint = line.split()
            out[name] = int(codepoint, 16)
    return out


class Face:
    """A font to draw glyphs from (optionally a variable-font instance)."""

    def __init__(self, data: bytes, axes=None):
        self.cmap = TTFont(io.BytesIO(data)).getBestCmap()
        self.font = ImageFont.truetype(io.BytesIO(data), CELL)
        if axes is not None:
            self.font.set_variation_by_axes(axes)

    def has(self, codepoint: int) -> bool:
        return codepoint in self.cmap


def layout():
    """Assigns every icon name a cell: (source, codepoint) pairs, shared by aliases."""
    legacy = parse_codepoints(fetch(LEGACY_CODEPOINTS).decode())
    symbols = parse_codepoints(fetch(SYMBOLS.format("Outlined") + ".codepoints").decode())
    for alias, target in ALIASES.items():
        legacy[alias] = legacy[target]
    missing = [name for name in CORE if name not in legacy]
    assert not missing, f"CORE icons missing from Material Icons: {missing}"

    order = CORE + sorted(set(legacy) - set(CORE)) + sorted(set(symbols) - set(legacy))
    cells, cell_of, index = [], {}, {}
    for name in order:
        key = ("legacy", legacy[name]) if name in legacy else ("symbols", symbols[name])
        if key not in cell_of:
            cell_of[key] = len(cells)
            cells.append({"key": key, "names": []})
        cells[cell_of[key]]["names"].append(name)
        index[name] = cell_of[key]
    return legacy, symbols, cells, index


def render(style, legacy, symbols, cells, legacy_filled, symbol_faces):
    legacy_source, (family, fill) = STYLES[style]
    data = legacy_source.read_bytes() if isinstance(legacy_source, Path) else fetch(legacy_source)
    own = Face(data)
    sym = symbol_faces[(family, fill)]

    def pick(cell):
        source, codepoint = cell["key"]
        if source == "symbols":
            return sym, codepoint
        if own.has(codepoint):
            return own, codepoint
        # A few newer icons are only in the Filled Material Icons font: use
        # this style's Material Symbols version when there is one.
        for name in cell["names"]:
            if name in symbols and sym.has(symbols[name]):
                return sym, symbols[name]
        return legacy_filled, codepoint

    folder = OUT / style
    if folder.exists():
        shutil.rmtree(folder)
    folder.mkdir(parents=True)
    pages = math.ceil(len(cells) / PER_PAGE)
    for page in range(pages):
        chunk = cells[page * PER_PAGE : (page + 1) * PER_PAGE]
        rows = math.ceil(len(chunk) / COLUMNS)
        sheet = Image.new("RGBA", (COLUMNS * PITCH, rows * PITCH), (255, 255, 255, 0))
        draw = ImageDraw.Draw(sheet)
        for i, cell in enumerate(chunk):
            face, codepoint = pick(cell)
            assert face.has(codepoint), f"{style}: no glyph for {cell['names']}"
            x = (i % COLUMNS) * PITCH + GUTTER
            y = (i // COLUMNS) * PITCH + GUTTER
            # Both font families put the glyph's one-em box on the baseline
            # (Material Icons: ascent = em, descent = 0; Material Symbols
            # glyphs likewise span 0..em), so the baseline is the cell bottom.
            draw.text((x, y + CELL), chr(codepoint), font=face.font, fill=(255, 255, 255, 255), anchor="ls")
        sheet.save(folder / f"{page}.png", optimize=True)
    size = sum(p.stat().st_size for p in folder.iterdir())
    print(f"wrote assets/icons/{style}/0..{pages - 1}.png ({size // 1024} KB)")
    return pages


def write_lua(legacy, cells, index, pages):
    lines = [
        "-- Generated by tools/build_icon_sheets.py; do not edit by hand.",
        "-- Geometry of the paged icon sprite sheets (assets/icons/<Style>/<page>.png),",
        "-- every icon name's cell (0-based across pages: page = cell // PerPage) and,",
        "-- for names Google's Material Icons fonts have, their codepoint there.",
        "local IconSheet = {",
        f"\tVersion = {VERSION}, -- layout version; part of cached file names",
        f"\tCell = {CELL}, -- icon size in px",
        f"\tPitch = {PITCH}, -- distance between cells (cell + gutters)",
        f"\tGutter = {GUTTER},",
        f"\tColumns = {COLUMNS},",
        f"\tRows = {ROWS}, -- per full page",
        f"\tPerPage = {PER_PAGE},",
        f"\tPages = {pages},",
        f"\tCount = {len(cells)}, -- distinct glyphs",
        "\tIndex = {}, -- name -> cell",
        "\tCodepoints = {}, -- name -> Material Icons font codepoint",
        "}",
        "",
        "-- One icon per line: name, cell, then its Material Icons codepoint (hex)",
        "-- unless it is a Material Symbols-only icon.",
        "local DATA = [[",
    ]
    for name in sorted(index):
        codepoint = f" {legacy[name]:x}" if name in legacy else ""
        lines.append(f"{name} {index[name]}{codepoint}")
    lines += [
        "]]",
        "",
        'for name, cell, codepoint in string.gmatch(DATA, "([%w_]+) (%d+) ?(%x*)") do',
        "\tIconSheet.Index[name] = tonumber(cell)",
        '\tif codepoint ~= "" then',
        "\t\tIconSheet.Codepoints[name] = tonumber(codepoint, 16)",
        "\tend",
        "end",
        "",
        "return IconSheet",
        "",
    ]
    SHEET_LUA.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {SHEET_LUA.relative_to(ROOT)} ({len(index)} names, {len(cells)} glyphs, {pages} pages)")


def main():
    legacy, symbols, cells, index = layout()
    legacy_filled = Face(fetch(STYLES["Filled"][0]))
    symbol_faces = {}
    for _, (family, fill) in STYLES.values():
        if (family, fill) not in symbol_faces:
            data = fetch(SYMBOLS.format(family) + ".ttf")
            # Axes in font order: FILL, GRAD, opsz, wght (regular, 24 dp)
            symbol_faces[(family, fill)] = Face(data, [fill, 0, 24, 400])
    pages = 0
    for style in STYLES:
        pages = render(style, legacy, symbols, cells, legacy_filled, symbol_faces)
    write_lua(legacy, cells, index, pages)


if __name__ == "__main__":
    main()
