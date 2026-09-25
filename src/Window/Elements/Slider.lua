-- Tab:AddSlider({ Title = "WalkSpeed", Min = 16, Max = 200, Default = 16, Step = 1, Suffix = "", Flag = "WS", Callback = function(v) end })
-- The value box on the right is editable: type a number and press Enter.
local Root = script.Parent.Parent.Parent
local Base = require(script.Parent.Base)
local Create = require(Root.Util.Create)
local Typography = require(Root.Core.Typography)
local Slider = require(Root.Components.Slider)

return function(container, props)
	local element = Base.Element(container, props, "Slider")
	local window = element._window
	local themer = window._themer

	local min = props.Min or 0
	local max = props.Max or 100
	local step = props.Step or props.Increment or props.Rounding or 1
	local suffix = props.Suffix or ""
	local decimals = step > 0 and #(tostring(step):match("%.(%d+)$") or "") or 2

	local function snap(value)
		value = tonumber(value) or min
		if step > 0 then
			value = math.round(value / step) * step
		end
		return math.clamp(value, min, max)
	end
	local function format(value)
		return string.format(`%.{decimals}f`, value) .. suffix
	end

	element.Value = snap(props.Default or props.Value or min)

	local row = Base.Row(element, props, { ControlWidth = 88, ControlHeight = 28 })

	local box = Create("TextBox") {
		Name = "Value",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ClearTextOnFocus = false,
		Text = format(element.Value),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row.Control,
	}
	Typography.Apply(box, "TitleSmall")
	themer:Bind(box, { TextColor3 = "Primary" })

	local extra = row.Extra()
	Create("UIPadding") {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		Parent = extra,
	}
	local slider = Slider.new({
		Min = min,
		Max = max,
		Step = step > 0 and step or nil,
		Value = element.Value,
		Theme = window.Theme,
		Size = UDim2.new(1, 0, 0, 28),
		Parent = extra,
	})
	element._maid:GiveTask(slider)

	element._normalize = snap
	element._render = function(value)
		slider:SetValue(value, true)
		box.Text = format(value)
	end

	element._maid:GiveTask(slider.Changed:Connect(function(value)
		value = snap(value)
		element.Value = value
		box.Text = format(value)
		element:_emit(value)
	end))
	element._maid:GiveTask(box.FocusLost:Connect(function()
		local typed = tonumber((box.Text:gsub("[^%d%.%-]", "")))
		if typed then
			element:Set(typed)
		else
			box.Text = format(element.Value)
		end
	end))

	return Base.Finish(element)
end
