-- Material 3 type scale, mapped onto Roblox Font/TextSize/LineHeight properties.
local Typography = {}

local REGULAR = Font.fromEnum(Enum.Font.Gotham)
local MEDIUM = Font.fromEnum(Enum.Font.GothamMedium)

-- size = TextSize (px), lineHeight = TextSize multiplier Roblox understands (LineHeight prop, 0-2 scale-ish "relative")
local SCALE = {
	DisplayLarge = { size = 57, lineHeight = 1.12, font = REGULAR },
	DisplayMedium = { size = 45, lineHeight = 1.16, font = REGULAR },
	DisplaySmall = { size = 36, lineHeight = 1.22, font = REGULAR },

	HeadlineLarge = { size = 32, lineHeight = 1.25, font = REGULAR },
	HeadlineMedium = { size = 28, lineHeight = 1.29, font = REGULAR },
	HeadlineSmall = { size = 24, lineHeight = 1.33, font = REGULAR },

	TitleLarge = { size = 22, lineHeight = 1.27, font = REGULAR },
	TitleMedium = { size = 16, lineHeight = 1.5, font = MEDIUM },
	TitleSmall = { size = 14, lineHeight = 1.43, font = MEDIUM },

	BodyLarge = { size = 16, lineHeight = 1.5, font = REGULAR },
	BodyMedium = { size = 14, lineHeight = 1.43, font = REGULAR },
	BodySmall = { size = 12, lineHeight = 1.33, font = REGULAR },

	LabelLarge = { size = 14, lineHeight = 1.43, font = MEDIUM },
	LabelMedium = { size = 12, lineHeight = 1.33, font = MEDIUM },
	LabelSmall = { size = 11, lineHeight = 1.45, font = MEDIUM },
}

Typography.Scale = SCALE

-- Applies a type-scale role onto a TextLabel/TextButton/TextBox.
function Typography.Apply(textObject: TextLabel | TextButton | TextBox, role: string)
	local style = SCALE[role]
	assert(style, `Unknown typography role "{role}"`)
	textObject.FontFace = style.font
	textObject.TextSize = style.size
	textObject.LineHeight = style.lineHeight
	textObject.RichText = false
end

return Typography
