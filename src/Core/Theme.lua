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

function Theme.new(seed: Color3?, mode: string?)
	local self = setmetatable({}, Theme)
	self.Seed = seed or DEFAULT_SEED
	self.Mode = mode or "Light"
	self._palettes = buildPalettes(self.Seed)
	self.Colors = buildScheme(self._palettes, self.Mode == "Dark")
	self.Changed = Signal.new()
	return self
end

function Theme:SetMode(mode: string)
	assert(mode == "Light" or mode == "Dark", "mode must be \"Light\" or \"Dark\"")
	if self.Mode == mode then
		return
	end
	self.Mode = mode
	self.Colors = buildScheme(self._palettes, mode == "Dark")
	self.Changed:Fire(self)
end

function Theme:Toggle()
	self:SetMode(self.Mode == "Light" and "Dark" or "Light")
end

function Theme:SetSeedColor(seed: Color3)
	self.Seed = seed
	self._palettes = buildPalettes(seed)
	self.Colors = buildScheme(self._palettes, self.Mode == "Dark")
	self.Changed:Fire(self)
end

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
