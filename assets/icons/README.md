# Material Icons sprite sheets

`MaterialIcons{Outlined,Filled,Round,Sharp}.png` are the icons listed in
`src/Core/Icons.lua`, rendered white on transparency from Google's Material
Icons fonts ([google/material-design-icons](https://github.com/google/material-design-icons),
Apache License 2.0, see `../fonts/LICENSE`) by
[`tools/build_icon_sheets.py`](../../tools/build_icon_sheets.py).

Layout: 12 columns, 64 px cells with a 4 px transparent gutter (72 px pitch);
the cell index of every icon is in `src/Core/IconSheet.lua`. At runtime the
sheet is downloaded once, loaded with `getcustomasset`, and each icon is cut
out with `ImageRectOffset` / `ImageRectSize` and tinted with `ImageColor3`.

To add icons: add the name + codepoint to `CODEPOINTS` in `Icons.lua`, then
run `python3 tools/build_icon_sheets.py` and `python3 tools/bundle.py`.
