--[[
	Material Design flat-icon glyph support.

	Roblox has no built-in Material Symbols font, so real MD icons need a font
	*asset* — there is no way to ship the actual glyph shapes without one.
	This module gets you there without image assets per icon: one font
	covers every glyph below, rendered as ordinary colorable text (so it
	tints, resizes and themes exactly like a TextLabel).

	Setup (one-time per game):
		1. Download a Material Icons .ttf: assets/fonts/MaterialIconsOutlined-Regular.ttf
		   in this repo (Outlined, the M3 look), or font/MaterialIcons-Regular.ttf
		   from https://github.com/google/material-design-icons (Filled). Apache-2.0.
		2. Upload it to Roblox Studio as a Font asset (Toolbox > your fonts,
		   or Asset Manager) and copy its rbxassetid.
		3. MD3.Icons.SetFont(Font.new("rbxassetid://<your id>"))

	On executors, MD3.IconFont.Load() does all of that automatically
	(Outlined by default; Filled / Round / Sharp also available). All four
	styles share the codepoints below.

	Until SetFont is called, Icons.Apply() falls back to Roblox's own
	BuilderIcons font, which ships inside every Roblox client (no download,
	no asset upload; icons are ligatures, i.e. the text "gear" renders as a
	gear). Material names are mapped onto the closest BuilderIcons glyph.
	Names with no BuilderIcons match fall back to a small set of plain glyph
	characters, so components never show a blank/tofu box.

	Any BuilderIcons glyph can also be used directly: Icons.Apply(label, "builder:sword").

	local Icons = MD3.Icons
	Icons.Apply(myTextLabel, "settings")   -- sets FontFace + Text
	Icons.Glyph("settings")                -- just the character, if you want
	                                        -- to lay it out yourself
]]
local Icons = {}

-- Codepoints copied from Google's official Material Icons codepoint map
-- (material-design-icons repo, font/MaterialIcons-Regular.codepoints).
-- The variable-weight "Material Symbols" font that Google ships today keeps
-- the same codepoints for this common subset, so this table works with either.
local CODEPOINTS = {
	add = 0xe145,
	alarm = 0xe855,
	arrow_back = 0xe5c4,
	arrow_drop_down = 0xe5c5,
	arrow_drop_up = 0xe5c7,
	arrow_forward = 0xe5c8,
	attach_file = 0xe226,
	auto_awesome = 0xe65f,
	autorenew = 0xe863,
	backpack = 0xf19c,
	bar_chart = 0xe26b,
	block = 0xe14b,
	bolt = 0xea0b,
	bookmark = 0xe866,
	bookmark_border = 0xe867,
	brightness_dark = 0xe3a9,
	brightness_light = 0xe3ac,
	build = 0xe869,
	calendar_today = 0xe935,
	camera_alt = 0xe3b0,
	cancel = 0xe5c9,
	chat = 0xe0b7,
	check = 0xe5ca,
	check_box = 0xe834,
	check_box_outline_blank = 0xe835,
	check_circle = 0xe86c,
	chevron_left = 0xe5cb,
	chevron_right = 0xe5cc,
	close = 0xe5cd,
	close_fullscreen = 0xf1cf,
	cloud = 0xe2bd,
	code = 0xe86f,
	colorize = 0xe3b8,
	comment = 0xe0b9,
	content_copy = 0xe14d,
	credit_card = 0xe870,
	dark_mode = 0xe51c,
	dashboard = 0xe871,
	delete = 0xe872,
	done = 0xe876,
	download = 0xf090,
	drag_handle = 0xe25d,
	drag_indicator = 0xe945,
	edit = 0xe3c9,
	error = 0xe000,
	event = 0xe878,
	expand_less = 0xe5ce,
	expand_more = 0xe5cf,
	explore = 0xe87a,
	fast_forward = 0xe01f,
	fast_rewind = 0xe020,
	favorite = 0xe87d,
	filter_list = 0xe152,
	flag = 0xe153,
	folder = 0xe2c7,
	fullscreen = 0xe5d0,
	fullscreen_exit = 0xe5d1,
	grid_view = 0xe9b0,
	group = 0xe7ef,
	groups = 0xf233,
	help_outline = 0xe8fd,
	history = 0xe889,
	home = 0xe88a,
	image = 0xe3f4,
	info = 0xe88e,
	keyboard = 0xe312,
	keyboard_arrow_down = 0xe313,
	keyboard_arrow_left = 0xe314,
	keyboard_arrow_right = 0xe315,
	keyboard_arrow_up = 0xe316,
	language = 0xe894,
	light_mode = 0xe518,
	link = 0xe157,
	list = 0xe896,
	location_on = 0xe0c8,
	lock = 0xe897,
	lock_open = 0xe898,
	login = 0xea77,
	logout = 0xe9ba,
	mail = 0xe158,
	menu = 0xe5d2,
	mic = 0xe029,
	mic_off = 0xe02b,
	minimize = 0xe931,
	more_horiz = 0xe5d3,
	more_vert = 0xe5d4,
	notifications = 0xe7f4,
	open_in_full = 0xf1ce,
	open_in_new = 0xe89e,
	palette = 0xe40a,
	pause = 0xe034,
	person = 0xe7fd,
	play_arrow = 0xe037,
	priority_high = 0xe645,
	public = 0xe80b,
	radio_button_checked = 0xe837,
	radio_button_unchecked = 0xe836,
	refresh = 0xe5d5,
	remove = 0xe15b,
	reorder = 0xe8fe,
	report = 0xe160,
	save = 0xe161,
	schedule = 0xe8b5,
	search = 0xe8b6,
	send = 0xe163,
	settings = 0xe8b8,
	share = 0xe80d,
	shield = 0xe9e0,
	shopping_cart = 0xe8cc,
	skip_next = 0xe044,
	skip_previous = 0xe045,
	sort = 0xe164,
	speed = 0xe9e4,
	sports_esports = 0xea28,
	star = 0xe838,
	stop = 0xe047,
	swap_horiz = 0xe8d4,
	swap_vert = 0xe8d5,
	sync = 0xe627,
	tag = 0xe9ef,
	terminal = 0xeb8e,
	thumb_down = 0xe8db,
	thumb_up = 0xe8dc,
	timer = 0xe425,
	toggle_off = 0xe9f5,
	toggle_on = 0xe9f6,
	touch_app = 0xe913,
	tune = 0xe429,
	upload = 0xf09b,
	verified = 0xef76,
	visibility = 0xe8f4,
	visibility_off = 0xe8f5,
	volume_off = 0xe04f,
	volume_up = 0xe050,
	warning = 0xe002,
	widgets = 0xe1bd,
	wifi = 0xe63e,
	zoom_in = 0xe8ff,
	zoom_out = 0xe900,
}

-- Plain-character stand-ins used only until a real icon font is configured.
local FALLBACK_GLYPHS = {
	check = "\u{2713}",
	check_box = "\u{2713}",
	radio_button_checked = "\u{25CF}",
	radio_button_unchecked = "\u{25CB}",
	remove = "\u{2212}",
	close = "\u{2715}",
	cancel = "\u{2715}",
	add = "+",
	arrow_back = "\u{2190}",
	arrow_forward = "\u{2192}",
	chevron_left = "\u{2039}",
	chevron_right = "\u{203A}",
	expand_more = "\u{2304}",
	expand_less = "\u{2303}",
	minimize = "\u{2212}",
	menu = "\u{2261}",
	done = "\u{2713}",
}

-- Roblox's built-in ligature icon font (the same one the Roblox app UI
-- uses). Font.new doesn't throw for a missing file, so this is safe to
-- create even if Roblox moves it; SetBuilderIconsEnabled(false) opts out.
local BUILDER_FONT = Font.new(
	"rbxasset://LuaPackages/Packages/_Index/BuilderIcons/BuilderIcons/BuilderIcons.json",
	Enum.FontWeight.Regular,
	Enum.FontStyle.Normal
)

-- Material icon name -> closest BuilderIcons ligature.
local BUILDER_NAMES = {
	add = "plus-large",
	alarm = "bell-clock",
	arrow_back = "arrow-large-left",
	arrow_drop_down = "caret-small-down",
	arrow_drop_up = "caret-small-up",
	arrow_forward = "arrow-large-right",
	attach_file = "chain-link",
	autorenew = "arrow-rotate-right",
	backpack = "backpack",
	bar_chart = "chart-three-vertical-bars",
	block = "circle-slash",
	bolt = "lightning-bolt",
	bookmark = "bookmark",
	build = "hammer-code",
	calendar_today = "calendar",
	camera_alt = "photo-camera",
	cancel = "circle-x",
	chat = "speech-bubble-round",
	check = "check",
	check_box = "square-check",
	check_circle = "circle-check",
	chevron_left = "chevron-large-left",
	chevron_right = "chevron-large-right",
	close = "x",
	cloud = "cloud",
	code = "code",
	comment = "speech-bubble-round",
	content_copy = "two-stacked-squares",
	credit_card = "wallet",
	dark_mode = "moon",
	dashboard = "squares-grid-plus",
	delete = "trash-can",
	done = "check",
	download = "arrow-down-to-line",
	drag_handle = "three-bars-horizontal",
	drag_indicator = "six-dots-two-column-grid",
	edit = "pencil",
	error = "triangle-exclamation",
	event = "calendar",
	expand_less = "chevron-small-up",
	expand_more = "chevron-small-down",
	explore = "compass",
	favorite = "heart",
	flag = "flag",
	folder = "folder",
	fullscreen = "dual-arrows-to-corners",
	grid_view = "grid",
	group = "two-people",
	groups = "three-people",
	help_outline = "circle-question",
	history = "clock",
	home = "house",
	image = "image",
	info = "circle-i",
	keyboard_arrow_down = "chevron-small-down",
	keyboard_arrow_left = "chevron-small-left",
	keyboard_arrow_right = "chevron-small-right",
	keyboard_arrow_up = "chevron-small-up",
	language = "globe-simplified",
	light_mode = "sun",
	link = "chain-link",
	list = "list-bulleted",
	location_on = "location-pin",
	lock = "lock-closed",
	login = "door-open-arrow-to-bottom-right",
	mail = "envelope",
	menu = "three-bars-horizontal",
	mic = "microphone",
	mic_off = "microphone-slash",
	minimize = "minus",
	more_horiz = "three-dots-horizontal",
	more_vert = "three-dots-vertical",
	notifications = "bell",
	open_in_new = "arrow-up-right-from-square",
	palette = "paint-brush",
	pause = "pause-large",
	person = "person",
	play_arrow = "play-large",
	public = "globe-simplified",
	refresh = "arrow-rotate-right",
	remove = "minus",
	reorder = "four-bars-horizontal-justified-aligned",
	search = "magnifying-glass",
	send = "paper-airplane",
	settings = "gear",
	shield = "shield-check",
	shopping_cart = "shopping-cart",
	skip_next = "skip-next-large",
	skip_previous = "skip-previous-large",
	sports_esports = "controller-with-cog",
	star = "star",
	stop = "stop-large",
	swap_horiz = "two-arrows-left-right",
	swap_vert = "two-arrows-down-and-up",
	sync = "arrow-rotate-right",
	tag = "hashtag",
	thumb_down = "thumb-down",
	thumb_up = "thumb-up",
	timer = "clock",
	schedule = "clock",
	tune = "three-sliders-horizontal",
	verified = "verified-check",
	visibility = "eye",
	visibility_off = "eye-slash",
	volume_off = "speaker-slash",
	volume_up = "speaker",
	warning = "triangle-exclamation",
	widgets = "nine-dots-grid",
	zoom_in = "magnifying-glass-plus",
	zoom_out = "magnifying-glass-minus",
}

Icons.Codepoints = CODEPOINTS
Icons.BuilderNames = BUILDER_NAMES
Icons.BuilderFont = BUILDER_FONT

local iconFont: Font? = nil

-- Call once at startup after uploading a Material Symbols/Icons font asset.
function Icons.SetFont(font: Font)
	iconFont = font
end

function Icons.HasFont(): boolean
	return iconFont ~= nil
end

function Icons.GetFont(): Font?
	return iconFont
end

local builderEnabled = true

-- BuilderIcons is on by default; turn it off to use only the Material font
-- and the plain-character fallbacks.
function Icons.SetBuilderIconsEnabled(enabled: boolean)
	builderEnabled = enabled
end

-- Resolves `name` to the text to display and the font to display it in
-- (nil font = keep the label's own font). Priority: Material font ->
-- BuilderIcons -> plain character.
function Icons.Resolve(name: string): (string, Font?)
	local builderName = name:match("^builder:(.+)$")
	if builderName then
		return builderName, BUILDER_FONT
	end
	if iconFont and CODEPOINTS[name] then
		return utf8.char(CODEPOINTS[name]), iconFont
	end
	if builderEnabled and BUILDER_NAMES[name] then
		return BUILDER_NAMES[name], BUILDER_FONT
	end
	return FALLBACK_GLYPHS[name] or (CODEPOINTS[name] and utf8.char(CODEPOINTS[name])) or "?", nil
end

-- The text Icons.Apply would put on a label for `name`.
function Icons.Glyph(name: string): string
	return (Icons.Resolve(name))
end

-- True when `name` renders as something meaningful right now (a Material
-- glyph with the font set, a BuilderIcons glyph, or a plain fallback).
function Icons.CanRender(name: string): boolean
	if type(name) ~= "string" then
		return false
	end
	return name:match("^builder:.+") ~= nil
		or (iconFont ~= nil and CODEPOINTS[name] ~= nil)
		or (builderEnabled and BUILDER_NAMES[name] ~= nil)
		or FALLBACK_GLYPHS[name] ~= nil
end

-- Adds (or overrides) a glyph by codepoint, e.g. one from the official
-- MaterialIcons-Regular.codepoints file that isn't in the table above.
function Icons.Register(name: string, codepoint: number)
	CODEPOINTS[name] = codepoint
end

-- Applies the icon glyph + matching font onto a Text object in one call.
function Icons.Apply(textObject: TextLabel | TextButton, name: string)
	local text, font = Icons.Resolve(name)
	textObject.Text = text
	if font then
		textObject.FontFace = font
	end
end

return Icons
