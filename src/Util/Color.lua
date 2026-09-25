-- Color math used to build Material 3 tonal palettes from a single seed color.
-- Note: this uses HSL as a practical stand-in for Google's HCT color space.
-- It reproduces the *shape* of M3 tonal palettes (13 tones per hue, consistent
-- contrast between roles) without needing the full CAM16 implementation.
local Color = {}

function Color.RGBToHSL(color: Color3)
	local r, g, b = color.R, color.G, color.B
	local max, min = math.max(r, g, b), math.min(r, g, b)
	local h, s, l = 0, 0, (max + min) / 2

	if max ~= min then
		local d = max - min
		s = l > 0.5 and d / (2 - max - min) or d / (max + min)
		if max == r then
			h = (g - b) / d + (g < b and 6 or 0)
		elseif max == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h = h / 6
	end

	return h, s, l
end

local function hueToRGB(p, q, t)
	if t < 0 then
		t += 1
	end
	if t > 1 then
		t -= 1
	end
	if t < 1 / 6 then
		return p + (q - p) * 6 * t
	end
	if t < 1 / 2 then
		return q
	end
	if t < 2 / 3 then
		return p + (q - p) * (2 / 3 - t) * 6
	end
	return p
end

function Color.HSLToRGB(h: number, s: number, l: number): Color3
	if s <= 0 then
		return Color3.new(l, l, l)
	end

	local q = l < 0.5 and l * (1 + s) or l + s - l * s
	local p = 2 * l - q

	local r = hueToRGB(p, q, h + 1 / 3)
	local g = hueToRGB(p, q, h)
	local b = hueToRGB(p, q, h - 1 / 3)

	return Color3.new(r, g, b)
end

-- Blend two colors, `amount` is the weight of `to` (0-1).
function Color.Blend(from: Color3, to: Color3, amount: number): Color3
	amount = math.clamp(amount, 0, 1)
	return Color3.new(
		from.R + (to.R - from.R) * amount,
		from.G + (to.G - from.G) * amount,
		from.B + (to.B - from.B) * amount
	)
end

-- A "palette" is a hue + saturation pair; :Tone(t) produces the color at
-- lightness t/100, tapering saturation near the extremes like HCT chroma does.
local Palette = {}
Palette.__index = Palette

function Palette.new(hue: number, saturation: number)
	return setmetatable({ Hue = hue % 1, Saturation = math.clamp(saturation, 0, 1) }, Palette)
end

function Palette:Tone(tone: number): Color3
	local l = math.clamp(tone, 0, 100) / 100
	-- Taper saturation as we approach black/white so extreme tones don't clip oddly.
	local taper = 1 - math.abs(l - 0.5) * 2 * 0.35
	return Color.HSLToRGB(self.Hue, self.Saturation * taper, l)
end

function Color.PaletteFromSeed(seed: Color3, saturationOverride: number?, hueShift: number?): typeof(Palette.new(0, 0))
	local h, s, _ = Color.RGBToHSL(seed)
	h = (h + (hueShift or 0)) % 1
	return Palette.new(h, saturationOverride or math.max(s, 0.16))
end

Color.Palette = Palette

return Color
