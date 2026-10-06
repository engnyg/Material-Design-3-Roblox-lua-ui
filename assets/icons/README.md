# Material icon sprite sheets

`<Style>/<page>.png` (styles `Outlined`, `Filled`, `Round`, `Sharp`; pages
`0`-`22`) hold Google's whole Material icon set, rendered white on
transparency by [`tools/build_icon_sheets.py`](../../tools/build_icon_sheets.py)
from [google/material-design-icons](https://github.com/google/material-design-icons)
(Apache License 2.0, see `../fonts/LICENSE`):

- every Material Icons name (2,234), drawn from that style's Material Icons
  font, so filled / outlined variants match the font path, and
- every Material Symbols name the Material Icons fonts don't have (~2,100),
  drawn from the Material Symbols variable fonts (Outlined unfilled, the
  other styles filled), at weight 400, grade 0, optical size 24.

Layout: 14 columns x 14 rows per page, 64 px cells with a 4 px transparent
gutter (72 px pitch, 1008 px pages). The cell of every name (cell // 196 is
the page) and the Material Icons font codepoints are in
`src/Core/IconSheet.lua`. Page 0 starts with the icons the library draws
itself, so a window downloads only that page up front; the others are
downloaded (and cached in the executor workspace) the first time one of
their icons is shown.

To pick up icons Google adds later: run `python3 tools/build_icon_sheets.py`
(downloads the fonts and codepoint lists) and `python3 tools/bundle.py`. If
the layout changes, bump `VERSION` in the script so clients don't reuse
cached pages of the old layout.
