-- Tab:AddButton({ Title = "Rejoin", Description = "...", Icon = "refresh", Callback = function() end })
-- IconColor: a theme role ("Error", "Primary", ...) or a Color3; default "Icon".
local Base = require(script.Parent.Base)

return function(container, props)
	local element = Base.Element(container, props, "Button")
	local themer = element._window._themer
	element.Flag = nil -- buttons hold no value to save

	local row = Base.Row(element, props, { ClassName = "TextButton", ControlWidth = 24, ControlHeight = 24 })
	Base.Glyph(themer, props.Icon or "chevron_right", 24, props.IconColor or "Icon", row.Control)
	Base.Interactive(element, row.Frame)

	element._maid:GiveTask(row.Frame.Activated:Connect(function()
		element:_emit()
	end))

	-- Runs the callback as if the button was clicked.
	function element:Fire()
		self:_emit()
	end

	return Base.Finish(element)
end
