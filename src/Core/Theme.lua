-- Material 3 color system: builds a full light/dark color-role scheme from a
-- single seed color, and lets components subscribe to live theme changes
-- (mode switch, seed color / dynamic-color swap, contrast changes, etc).
local Color = require(script.Parent.Parent.Util.Color)
local Signal = require(script.Parent.Parent.Util.Signal)

local DEFAULT_SEED = Color3.fromHex("#6750A4") -- Material baseline seed

local Theme = {}
Theme.__index = Theme

local function buildPalettes(seed: Color3)
	return {
		Primary = Color.PaletteFromSeed(seed, 0.55, 0),
		Secondary = Color.PaletteFromSeed(seed, 0.18, 0),
		Tertiary = Color.PaletteFromSeed(seed, 0.30, 1 / 6), -- +60deg hue
		Neutral = Color.PaletteFromSeed(seed, 0.06, 0),
		NeutralVariant = Color.PaletteFromSeed(seed, 0.10, 0),
		Error = Color.Palette.new(0 / 360, 0.62), -- fixed red hue, like real M3
	}
end

local function buildScheme(p, isDark: boolean)
	local N, NV = p.Neutral, p.NeutralVariant

	if isDark then
		return {
			Primary = p.Primary:Tone(80),
			OnPrimary = p.Primary:Tone(20),
			PrimaryContainer = p.Primary:Tone(30),
			OnPrimaryContainer = p.Primary:Tone(90),

			Secondary = p.Secondary:Tone(80),
			OnSecondary = p.Secondary:Tone(20),
			SecondaryContainer = p.Secondary:Tone(30),
			OnSecondaryContainer = p.Secondary:Tone(90),

			Tertiary = p.Tertiary:Tone(80),
			OnTertiary = p.Tertiary:Tone(20),
			TertiaryContainer = p.Tertiary:Tone(30),
			OnTertiaryContainer = p.Tertiary:Tone(90),

			Error = p.Error:Tone(80),
			OnError = p.Error:Tone(20),
			ErrorContainer = p.Error:Tone(30),
			OnErrorContainer = p.Error:Tone(90),

			Background = N:Tone(6),
			OnBackground = N:Tone(90),
			Surface = N:Tone(6),
			OnSurface = N:Tone(90),
			SurfaceVariant = NV:Tone(30),
			OnSurfaceVariant = NV:Tone(80),

			Outline = NV:Tone(60),
			OutlineVariant = NV:Tone(30),
			Shadow = N:Tone(0),
			Scrim = N:Tone(0),

			InverseSurface = N:Tone(90),
			InverseOnSurface = N:Tone(20),
			InversePrimary = p.Primary:Tone(40),

			SurfaceDim = N:Tone(6),
			SurfaceBright = N:Tone(24),
			SurfaceContainerLowest = N:Tone(4),
			SurfaceContainerLow = N:Tone(10),
			SurfaceContainer = N:Tone(12),
			SurfaceContainerHigh = N:Tone(17),
			SurfaceContainerHighest = N:Tone(22),
		}
	end

	return {
		Primary = p.Primary:Tone(40),
		OnPrimary = p.Primary:Tone(100),
		PrimaryContainer = p.Primary:Tone(90),
		OnPrimaryContainer = p.Primary:Tone(10),

		Secondary = p.Secondary:Tone(40),
		OnSecondary = p.Secondary:Tone(100),
		SecondaryContainer = p.Secondary:Tone(90),
		OnSecondaryContainer = p.Secondary:Tone(10),

		Tertiary = p.Tertiary:Tone(40),
		OnTertiary = p.Tertiary:Tone(100),
		TertiaryContainer = p.Tertiary:Tone(90),
		OnTertiaryContainer = p.Tertiary:Tone(10),

		Error = p.Error:Tone(40),
		OnError = p.Error:Tone(100),
		ErrorContainer = p.Error:Tone(90),
		OnErrorContainer = p.Error:Tone(10),

		Background = N:Tone(98),
		OnBackground = N:Tone(10),
		Surface = N:Tone(98),
		OnSurface = N:Tone(10),
		SurfaceVariant = NV:Tone(90),
		OnSurfaceVariant = NV:Tone(30),

		Outline = NV:Tone(50),
		OutlineVariant = NV:Tone(80),
		Shadow = N:Tone(0),
		Scrim = N:Tone(0),

		InverseSurface = N:Tone(20),
		InverseOnSurface = N:Tone(95),
		InversePrimary = p.Primary:Tone(80),

		SurfaceDim = N:Tone(87),
		SurfaceBright = N:Tone(98),
		SurfaceContainerLowest = N:Tone(100),
		SurfaceContainerLow = N:Tone(96),
		SurfaceContainer = N:Tone(94),
		SurfaceContainerHigh = N:Tone(92),
		SurfaceContainerHighest = N:Tone(90),
	}
end

-- Roles whose "On" color (text/icons drawn on top) is recomputed for
-- contrast when the role is overridden but its On role isn't.
local ON_PAIRS = {
	Primary = "OnPrimary",
	PrimaryContainer = "OnPrimaryContainer",
	Secondary = "OnSecondary",
	SecondaryContainer = "OnSecondaryContainer",
	Tertiary = "OnTertiary",
	TertiaryContainer = "OnTertiaryContainer",
	Error = "OnError",
	ErrorContainer = "OnErrorContainer",
	Surface = "OnSurface",
	Background = "OnBackground",
}

-- Relative luminance (WCAG) of a color, 0..1.
local function luminance(c: Color3): number
	local function channel(v)
		return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * channel(c.R) + 0.7152 * channel(c.G) + 0.0722 * channel(c.B)
end

-- Readable content color for a background: near-black or near-white.
function Theme:ContrastColor(background: Color3): Color3
	local N = self._palettes.Neutral
	return luminance(background) > 0.18 and N:Tone(10) or N:Tone(98)
end

-- The generated scheme, then the user's overrides on top. Also derives the
-- icon roles, which default to the M3 roles icons normally use:
--   Icon         = OnSurfaceVariant      (regular icons)
--   IconAccent   = Primary               (app icon, notification icons)
--   IconSelected = OnSecondaryContainer  (the selected navigation item)
-- Overrides cascade so one color can restyle a whole group:
--   * OnSurface (text) -> OnSurfaceVariant (secondary text, a softer mix of
--     the text and background colors) and OnBackground follow it
--   * Icon -> IconAccent and IconSelected follow it
-- unless those roles are overridden themselves.
function Theme:_build()
	local colors = buildScheme(self._palettes, self.Mode == "Dark")
	local overrides = self._overrides
	for role, color in overrides do
		colors[role] = color
	end
	for role, onRole in ON_PAIRS do
		if overrides[role] and not overrides[onRole] then
			colors[onRole] = self:ContrastColor(colors[role])
		end
	end
	if (overrides.OnSurface or overrides.Surface) and not overrides.OnSurfaceVariant then
		colors.OnSurfaceVariant = Color.Blend(colors.OnSurface, colors.Surface, 0.3)
	end
	if overrides.OnSurface and not overrides.OnBackground then
		colors.OnBackground = colors.OnSurface
	end
	colors.Icon = overrides.Icon or colors.OnSurfaceVariant
	colors.IconAccent = overrides.IconAccent or overrides.Icon or colors.Primary
	colors.IconSelected = overrides.IconSelected or overrides.Icon or colors.OnSecondaryContainer

	-- Transparency per role, cascading the same way as the colors.
	local t = self._transparency
	local transparency = table.clone(t)
	transparency.OnSurfaceVariant = t.OnSurfaceVariant or t.OnSurface
	transparency.OnBackground = t.OnBackground or t.OnSurface
	transparency.Icon = t.Icon or transparency.OnSurfaceVariant
	transparency.IconAccent = t.IconAccent or t.Icon
	transparency.IconSelected = t.IconSelected or t.Icon
	self.Transparency = transparency
	return colors
end

-- Transparency (0 = opaque, 1 = invisible) set for a color role, or nil
-- when the role is left opaque. Window chrome applies it through Themer to
-- the matching BackgroundTransparency / TextTransparency / ... property.
function Theme:GetTransparency(role: string): number?
	return self.Transparency[role]
end

-- One-call helpers for the three colors people most want to change.
-- nil returns that color to the generated default.
function Theme:SetThemeColor(color: Color3)
	self:SetSeedColor(color)
end

function Theme:SetTextColor(color: Color3?)
	self:SetOverride("OnSurface", color)
end

function Theme:SetIconColor(color: Color3?)
	self:SetOverride("Icon", color)
end

function Theme.new(seed: Color3?, mode: string?)
	local self = setmetatable({}, Theme)
	self.Seed = seed or DEFAULT_SEED
	self.Mode = mode or "Light"
	self._palettes = buildPalettes(self.Seed)
	self._overrides = {}
	self._transparency = {}
	self.Colors = self:_build()
	self.Changed = Signal.new()
	return self
end

function Theme:SetMode(mode: string)
	assert(mode == "Light" or mode == "Dark", "mode must be \"Light\" or \"Dark\"")
	if self.Mode == mode then
		return
	end
	self.Mode = mode
	self.Colors = self:_build()
	self.Changed:Fire(self)
end

function Theme:Toggle()
	self:SetMode(self.Mode == "Light" and "Dark" or "Light")
end

function Theme:SetSeedColor(seed: Color3)
	self.Seed = seed
	self._palettes = buildPalettes(seed)
	self.Colors = self:_build()
	self.Changed:Fire(self)
end

--== Overrides (theme editor) ==--

local function cleanTransparency(value)
	if type(value) ~= "number" then
		return nil
	end
	value = math.clamp(value, 0, 1)
	return if value > 0 then value else nil
end

-- Pins one color role (e.g. "Primary", "Surface", "Icon") to a fixed
-- color, on top of the seed-generated scheme. Survives SetSeedColor /
-- SetMode. `transparency` (0-1, optional) sets how see-through the role is;
-- leaving it out keeps the current one. color = nil resets the role
-- entirely (generated color, opaque).
function Theme:SetOverride(role: string, color: Color3?, transparency: number?)
	self._overrides[role] = color
	if color == nil then
		self._transparency[role] = nil
	elseif transparency ~= nil then
		self._transparency[role] = cleanTransparency(transparency)
	end
	self.Colors = self:_build()
	self.Changed:Fire(self)
end

-- Sets only a role's transparency (0-1; 0 or nil = opaque), keeping its color.
function Theme:SetTransparency(role: string, transparency: number?)
	self._transparency[role] = cleanTransparency(transparency)
	self.Colors = self:_build()
	self.Changed:Fire(self)
end

-- Replaces all overrides at once: colors ({ [role] = Color3 }) and,
-- optionally, transparencies ({ [role] = number }; nil keeps the current).
function Theme:SetOverrides(overrides: { [string]: Color3 }?, transparency: { [string]: number }?)
	self._overrides = table.clone(overrides or {})
	if transparency then
		self._transparency = {}
		for role, value in transparency do
			self._transparency[role] = cleanTransparency(value)
		end
	end
	self.Colors = self:_build()
	self.Changed:Fire(self)
end

function Theme:GetOverrides(): { [string]: Color3 }
	return table.clone(self._overrides)
end

function Theme:GetTransparencies(): { [string]: number }
	return table.clone(self._transparency)
end

function Theme:IsOverridden(role: string): boolean
	return self._overrides[role] ~= nil or self._transparency[role] ~= nil
end

function Theme:ClearOverrides()
	self:SetOverrides({}, {})
end

-- Plain table describing the theme (hex strings), e.g. to share as JSON:
-- { Seed = "6750a4", Mode = "Dark", Overrides = { Primary = "ff0000" },
--   Transparency = { Surface = 0.3 } }
function Theme:Export()
	local overrides = {}
	for role, color in self._overrides do
		overrides[role] = color:ToHex()
	end
	return {
		Seed = self.Seed:ToHex(),
		Mode = self.Mode,
		Overrides = overrides,
		Transparency = table.clone(self._transparency),
	}
end

-- Applies a table made by Export (one Changed event).
function Theme:Import(data)
	assert(type(data) == "table", "Theme:Import expects a table from Theme:Export")
	if data.Seed then
		self.Seed = Color3.fromHex(data.Seed)
		self._palettes = buildPalettes(self.Seed)
	end
	if data.Mode == "Light" or data.Mode == "Dark" then
		self.Mode = data.Mode
	end
	local overrides = {}
	for role, hex in data.Overrides or {} do
		overrides[role] = Color3.fromHex(hex)
	end
	self._overrides = overrides
	self._transparency = {}
	for role, value in data.Transparency or {} do
		self._transparency[role] = cleanTransparency(value)
	end
	self.Colors = self:_build()
	self.Changed:Fire(self)
end

-- Color roles worth exposing in an editor, with friendly names.
Theme.EditableRoles = {
	{ Role = "Primary", Name = "Primary" },
	{ Role = "Secondary", Name = "Secondary" },
	{ Role = "Tertiary", Name = "Tertiary" },
	{ Role = "SecondaryContainer", Name = "Selection" },
	{ Role = "Surface", Name = "Background" },
	{ Role = "SurfaceContainerLow", Name = "Content panel" },
	{ Role = "SurfaceContainerHigh", Name = "Rows" },
	{ Role = "OnSurface", Name = "Text" },
	{ Role = "OnSurfaceVariant", Name = "Secondary text" },
	{ Role = "Outline", Name = "Outline" },
	{ Role = "Icon", Name = "Icons" },
	{ Role = "IconAccent", Name = "Accent icons" },
	{ Role = "IconSelected", Name = "Selected tab icon" },
	{ Role = "Error", Name = "Error" },
}

-- Seed colors for quick theme presets (M3 baseline + common hues).
Theme.Presets = {
	{ Name = "Baseline", Seed = "6750A4" },
	{ Name = "Blue", Seed = "0061A4" },
	{ Name = "Teal", Seed = "006A6A" },
	{ Name = "Green", Seed = "006E1C" },
	{ Name = "Yellow", Seed = "6D5E0F" },
	{ Name = "Orange", Seed = "8B5000" },
	{ Name = "Red", Seed = "B3261E" },
	{ Name = "Pink", Seed = "984061" },
}

-- Surface tint overlay used to fake elevation (M3 uses a primary-tinted
-- overlay on top of Surface instead of a pure drop shadow to convey elevation).
local ELEVATION_OPACITY = { [0] = 0, 0.05, 0.08, 0.11, 0.12, 0.14 }

function Theme:SurfaceAtElevation(level: number): Color3
	level = math.clamp(level, 0, 5)
	return Color.Blend(self.Colors.Surface, self.Colors.Primary, ELEVATION_OPACITY[level])
end

-- Global default instance so components work out of the box without every
-- call site having to thread a theme object through.
local defaultTheme: typeof(Theme.new()) = nil

function Theme.Default()
	if not defaultTheme then
		defaultTheme = Theme.new()
	end
	return defaultTheme
end

Theme.DefaultSeed = DEFAULT_SEED

return Theme
