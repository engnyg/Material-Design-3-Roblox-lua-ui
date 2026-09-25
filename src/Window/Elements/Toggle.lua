-- Tab:AddToggle({ Title = "Auto farm", Default = false, Flag = "AutoFarm", Callback = function(on) end })
local Root = script.Parent.Parent.Parent
local Base = require(script.Parent.Base)
local Switch = require(Root.Components.Switch)

return function(container, props)
	local element = Base.Element(container, props, "Toggle")
	local window = element._window
	element.Value = (props.Default or props.Value) == true

	local row = Base.Row(element, props, { ClassName = "TextButton", ControlWidth = 52, ControlHeight = 32 })
	Base.Interactive(element, row.Frame)

	local switch = Switch.new({ Value = element.Value, Theme = window.Theme, Parent = row.Control })
	element._maid:GiveTask(switch)
	element._switch = switch

	element._normalize = function(value)
		return value == true
	end
	element._render = function(value)
		switch:SetValue(value, true)
	end

	element._maid:GiveTask(switch.Changed:Connect(function(value)
		element.Value = value
		element:_emit(value)
	end))
	-- Clicking anywhere on the row flips the switch too.
	element._maid:GiveTask(row.Frame.Activated:Connect(function()
		switch:SetValue(not switch:GetValue())
	end))

	return Base.Finish(element)
end
