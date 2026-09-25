# Material Icons fonts

`MaterialIcons{Outlined,Round,Sharp}-Regular.ttf` are Google's Material Icons
fonts from [google/material-design-icons](https://github.com/google/material-design-icons),
licensed under the Apache License 2.0 (see `LICENSE` in this folder).

Google publishes these styles only as `.otf` (CFF outlines). The files here
are the same fonts converted to TrueType outlines by
[`tools/convert_icon_fonts.py`](../../tools/convert_icon_fonts.py) so they
load reliably as Roblox custom fonts; glyph shapes, metrics and codepoints
are unchanged (cubic curves approximated with quadratics to within 0.5 font
units at 512 units/em). The Filled style (`MaterialIcons-Regular.ttf`) is
already TrueType and is downloaded straight from Google's repository.
