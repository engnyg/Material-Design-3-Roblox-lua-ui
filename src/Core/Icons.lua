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

	On executors none of this is needed: CreateWindow loads the icons as
	sprite-sheet *images* instead (MD3.IconImages, see Icons.SetSheet), which
	take priority over any font. The sheets hold Google's whole set, about
	4,300 names: every Material Icons name plus the Material Symbols (MD3)
	names the Material Icons fonts don't have. Browse them at
	https://fonts.google.com/icons, or Icons.Search("arrow") / Icons.Has(name).
	MD3.IconFont.Load() can still load the font (Outlined by default; Filled
	/ Round / Sharp also available); fonts only draw the Material Icons names.

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
local IconSheet = require(script.Parent.IconSheet)

local Icons = {}

-- Material Icons font codepoints for every name the fonts have (generated
-- from Google's MaterialIcons-Regular.codepoints into IconSheet.lua; all four
-- Material Icons styles share them). Material Symbols-only icons have no
-- entry: they exist only on the sprite sheets.
local CODEPOINTS = table.clone(IconSheet.Codepoints)

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
-- The icon sprite sheet: one image per page of IconSheet. Page 0 is set up
-- front; the others come from `sheetLoader` the first time one of their
-- icons is drawn.
local sheetPages: { [number]: string } = {} -- page -> content id
local sheetLoader: ((number) -> string?)? = nil
local pageState: { [number]: string } = {} -- page -> "loading" | "failed"
local sheetGeneration = 0 -- bumped by SetSheet so stale page loads are dropped

-- Every label Icons.Apply has drawn on, so switching the icon font (or
-- style) at runtime redraws icons that already exist. Strong keys with a
-- Destroying cleanup rather than weak keys: Roblox may recreate an
-- Instance's Lua wrapper, which would silently drop weak entries.
local applied = {} -- label -> icon name
local managed = {} -- labels whose Visible follows whether the icon can be drawn
local sprites = {} -- label -> ImageLabel showing the icon from the sprite sheet
local labelFonts = {} -- label -> the label's own font, for plain fallbacks
local cleanups = {}

local reapplyAll, draw

-- Sets the Material icon font (any style) and redraws every icon already
-- on screen with it.
function Icons.SetFont(font: Font)
	iconFont = font
	reapplyAll()
end

function Icons.HasFont(): boolean
	return iconFont ~= nil
end

function Icons.GetFont(): Font?
	return iconFont
end

-- Sets the icon sprite sheet and redraws every icon on screen with it; the
-- sheet takes priority over the font. `image` is page 0 (a content id, e.g.
-- from getcustomasset; see Executor/IconImages.lua, which loads one set of
-- pages per style). `loader(page)` returns another page's content id (or
-- nil if it can't); it may yield, and runs once per page, on first use.
-- Without a loader only page 0's icons come from the sheet. nil removes it.
function Icons.SetSheet(image: string?, loader: ((number) -> string?)?)
	sheetGeneration += 1
	sheetPages = {}
	pageState = {}
	if image ~= nil and image ~= "" then
		sheetPages[0] = image
		sheetLoader = loader
	else
		sheetLoader = nil
	end
	reapplyAll()
end

-- Page 0 of the current sprite sheet (nil when there is none).
function Icons.GetSheet(): string?
	return sheetPages[0]
end

-- The page a sheet icon is on, or nil if the sheet doesn't have it.
local function pageOf(name: string): number?
	local index = IconSheet.Index[name]
	return index and index // IconSheet.PerPage
end

local function redrawPage(page: number)
	for textObject, name in applied do
		if textObject.Parent and pageOf(name) == page then
			draw(textObject, name)
		end
	end
end

-- The content id of a sheet page, starting its download the first time.
-- Returns nil while it loads (icons on it are redrawn once it's there).
local function pageImage(page: number): string?
	if sheetPages[page] or not sheetLoader or pageState[page] then
		return sheetPages[page]
	end
	pageState[page] = "loading"
	local loader, generation = sheetLoader, sheetGeneration
	task.spawn(function()
		local ok, image = pcall(loader, page)
		if generation ~= sheetGeneration then
			return -- the sheet (style) changed meanwhile
		end
		if ok and type(image) == "string" and image ~= "" then
			sheetPages[page] = image
			pageState[page] = nil
			redrawPage(page)
		else
			pageState[page] = "failed"
		end
	end)
	return sheetPages[page] -- set already if the loader didn't yield
end

-- True when `name` is on the sprite sheet and its page is (or can be) loaded.
local function onSheet(name: string): boolean
	local page = pageOf(name)
	if page == nil or sheetPages[0] == nil then
		return false
	end
	return sheetPages[page] ~= nil or (sheetLoader ~= nil and pageState[page] ~= "failed")
end

local builderEnabled = true

-- BuilderIcons is on by default; turn it off to use only the Material font
-- and the plain-character fallbacks.
function Icons.SetBuilderIconsEnabled(enabled: boolean)
	builderEnabled = enabled
	reapplyAll()
end

-- Resolves `name` to the text to display and the font to display it in
-- (nil font = keep the label's own font) when it's drawn as text.
-- Priority: sprite sheet image (handled by Apply) -> Material font ->
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
	-- Never emit a bare Material codepoint without the Material font: those
	-- are Private Use Area characters, and system fallback fonts draw them
	-- as something unrelated (e.g. Chinese user-defined characters on
	-- Traditional Chinese Windows). Drawing nothing is better.
	return FALLBACK_GLYPHS[name] or "", nil
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
		or onSheet(name)
		or (iconFont ~= nil and CODEPOINTS[name] ~= nil)
		or (builderEnabled and BUILDER_NAMES[name] ~= nil)
		or FALLBACK_GLYPHS[name] ~= nil
end

-- Adds (or overrides) a font glyph by codepoint, e.g. one from a newer
-- MaterialIcons-Regular.codepoints file. Font only: the sprite sheets
-- can't gain icons at runtime.
function Icons.Register(name: string, codepoint: number)
	CODEPOINTS[name] = codepoint
end

-- True when `name` is a Material icon this library knows (on the sprite
-- sheets or registered for the font), whether or not it can be drawn now.
function Icons.Has(name: string): boolean
	return type(name) == "string" and (IconSheet.Index[name] ~= nil or CODEPOINTS[name] ~= nil)
end

-- Every known icon name containing `query` (plain text, case-insensitive;
-- nil / "" lists them all), sorted.
function Icons.Search(query: string?): { string }
	local needle = string.lower(query or "")
	local found, seen = {}, {}
	local function consider(name)
		if not seen[name] and (needle == "" or string.find(name, needle, 1, true)) then
			seen[name] = true
			table.insert(found, name)
		end
	end
	for name in IconSheet.Index do
		consider(name)
	end
	for name in CODEPOINTS do
		consider(name)
	end
	table.sort(found)
	return found
end

-- Keeps the sprite looking like the label's text would: same color,
-- transparency, size and layer.
local function syncSprite(textObject, sprite)
	sprite.ImageColor3 = textObject.TextColor3
	sprite.ImageTransparency = textObject.TextTransparency
	sprite.Size = if textObject.TextScaled
		then UDim2.fromScale(1, 1)
		else UDim2.fromOffset(textObject.TextSize, textObject.TextSize)
	sprite.ZIndex = textObject.ZIndex
end

local function spriteFor(textObject)
	local sprite = sprites[textObject]
	if sprite and sprite.Parent == textObject then
		return sprite
	end
	sprite = Instance.new("ImageLabel")
	sprite.Name = "MD3Icon"
	sprite.BackgroundTransparency = 1
	sprite.AnchorPoint = Vector2.new(0.5, 0.5)
	sprite.Position = UDim2.fromScale(0.5, 0.5)
	sprite.ScaleType = Enum.ScaleType.Fit
	sprite.ImageRectSize = Vector2.new(IconSheet.Cell, IconSheet.Cell)
	sprite.Parent = textObject
	sprites[textObject] = sprite
	for _, prop in { "TextColor3", "TextTransparency", "TextSize", "TextScaled", "ZIndex" } do
		textObject:GetPropertyChangedSignal(prop):Connect(function()
			if sprites[textObject] == sprite then
				syncSprite(textObject, sprite)
			end
		end)
	end
	return sprite
end

function draw(textObject, name: string)
	local index = IconSheet.Index[name]
	local image = index and sheetPages[0] and pageImage(index // IconSheet.PerPage)
	if image then
		local cell = index % IconSheet.PerPage
		local sprite = spriteFor(textObject)
		sprite.Image = image
		sprite.ImageRectOffset = Vector2.new(
			(cell % IconSheet.Columns) * IconSheet.Pitch + IconSheet.Gutter,
			(cell // IconSheet.Columns) * IconSheet.Pitch + IconSheet.Gutter
		)
		sprite.Visible = true
		syncSprite(textObject, sprite)
		textObject.Text = ""
		if managed[textObject] then
			textObject.Visible = true
		end
		return
	end

	if sprites[textObject] then
		sprites[textObject].Visible = false
	end
	local text, font = Icons.Resolve(name)
	textObject.Text = text
	textObject.FontFace = font or labelFonts[textObject] or textObject.FontFace
	if managed[textObject] then
		textObject.Visible = text ~= ""
	end
end

-- Applies the icon onto a Text object (TextLabel/TextButton) in one call:
-- as a sprite-sheet image when one is loaded, otherwise as a glyph. The
-- label keeps following later SetSheet / SetFont / style changes. With
-- `manageVisibility`, the label is hidden while the icon can't be drawn
-- and shown again once a source that has it arrives.
function Icons.Apply(textObject: TextLabel | TextButton, name: string, manageVisibility: boolean?)
	if applied[textObject] == nil then
		labelFonts[textObject] = textObject.FontFace
		local ok, connection = pcall(function()
			return textObject.Destroying:Connect(function()
				applied[textObject] = nil
				managed[textObject] = nil
				sprites[textObject] = nil
				labelFonts[textObject] = nil
				cleanups[textObject] = nil
			end)
		end)
		if ok then
			cleanups[textObject] = connection
		end
	end
	applied[textObject] = name
	if manageVisibility then
		managed[textObject] = true
	end
	draw(textObject, name)
end

function reapplyAll()
	for textObject, name in applied do
		if textObject.Parent then
			draw(textObject, name)
		end
	end
end

return Icons
