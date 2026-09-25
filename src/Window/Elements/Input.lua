--[[
	Tab:AddInput({
		Title = "Target player",
		Placeholder = "Username",
		Default = "",
		Numeric = false,        -- only allow number characters
		Finished = true,        -- fire on focus lost (false = on every keystroke)
		ClearOnSubmit = false,  -- empty the box after firing
		Flag = "Target",
		Callback = function(text) end,
	})
]]
local TweenService = game:GetService("TweenService")

local Root = script.Parent.Parent.Parent
local Base = require(script.Parent.Base)
local Create = require(Root.Util.Create)
local Typography = require(Root.Core.Typography)
local Motion = require(Root.Core.Motion)

return function(container, props)
	local element = Base.Element(container, props, "Input")
	local window = element._window
	local themer = window._themer
	local numeric = props.Numeric == true
	local finished = props.Finished ~= false

	local function clean(text)
		text = tostring(text or "")
		if numeric then
			text = text:gsub("[^%d%.%-]", "")
		end
		return text
	end

	element.Value = clean(props.Default or props.Value)

	local row = Base.Row(element, props, { ControlWidth = 170, ControlHeight = 32 })
	local field, stroke = Base.Field(themer, "TextBox", row.Control, UDim2.fromScale(1, 1))
	field.ClearTextOnFocus = false
	field.Text = element.Value
	field.PlaceholderText = props.Placeholder or props.PlaceholderText or ""
	field.TextXAlignment = Enum.TextXAlignment.Left
	field.TextTruncate = Enum.TextTruncate.AtEnd
	Typography.Apply(field, "BodyMedium")
	themer:Bind(field, { TextColor3 = "OnSurface", PlaceholderColor3 = "OnSurfaceVariant" })
	Create("UIPadding") {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = field,
	}

	element._normalize = clean
	element._render = function(value)
		field.Text = value
	end

	local function submit()
		element.Value = field.Text
		element:_emit(field.Text)
		if props.ClearOnSubmit or props.RemoveTextAfterFocusLost then
			field.Text = ""
			element.Value = ""
		end
	end

	element._maid:GiveTask(field:GetPropertyChangedSignal("Text"):Connect(function()
		local cleaned = clean(field.Text)
		if cleaned ~= field.Text then
			field.Text = cleaned
			return
		end
		-- Comparing against Value (instead of a "rendering" flag) also
		-- holds under deferred signal behavior.
		if not finished and cleaned ~= element.Value then
			element.Value = cleaned
			element:_emit(cleaned)
		end
	end))
	element._maid:GiveTask(field.Focused:Connect(function()
		themer:Bind(stroke, { Color = "Primary" })
		TweenService:Create(stroke, Motion.Standard(Motion.Duration.Short2), { Thickness = 2 }):Play()
	end))
	element._maid:GiveTask(field.FocusLost:Connect(function()
		themer:Bind(stroke, { Color = "OutlineVariant" })
		TweenService:Create(stroke, Motion.Standard(Motion.Duration.Short2), { Thickness = 1 }):Play()
		if finished then
			submit()
		end
	end))

	return Base.Finish(element)
end
