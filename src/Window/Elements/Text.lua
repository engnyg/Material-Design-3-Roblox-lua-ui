-- Non-interactive elements: Label, Paragraph, Divider.
local Root = script.Parent.Parent.Parent
local Base = require(script.Parent.Base)
local Create = require(Root.Util.Create)
local Typography = require(Root.Core.Typography)
local Divider = require(Root.Components.Divider)

local Text = {}

-- Tab:AddLabel("Some text") / Tab:AddLabel({ Text = "...", Color = "Primary" })
function Text.Label(container, props)
	if type(props) == "string" then
		props = { Text = props }
	end
	local element = Base.Element(container, props, "Label")
	local themer = element._window._themer
	element.Flag = nil
	element.Value = tostring(props.Text or props.Title or "")

	local label = Create("TextLabel") {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = element.Value,
		TextWrapped = true,
		RichText = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = container:_nextOrder(),
		[1] = Create("UIPadding") {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
		},
	}
	Typography.Apply(label, "BodyMedium")
	themer:Bind(label, { TextColor3 = props.Color or "OnSurfaceVariant" })
	label.Parent = container._holder
	element.Instance = label

	element._normalize = tostring
	element._render = function(value)
		label.Text = value
	end
	element._emit = function() end

	return element
end

-- Tab:AddParagraph({ Title = "Info", Content = "Longer text..." })
function Text.Paragraph(container, props)
	if type(props) == "string" then
		props = { Title = props }
	end
	local element = Base.Element(container, props, "Paragraph")
	element.Flag = nil
	Base.Row(element, props, {})
	element.Value = { Title = props.Title or "", Content = props.Content or props.Description or "" }

	element._render = function(value)
		element:SetTitle(value.Title or "")
		element:SetDescription(value.Content or "")
	end
	element._emit = function() end

	return element
end

-- Tab:AddDivider()
function Text.Divider(container, props)
	props = props or {}
	local element = Base.Element(container, props, "Divider")
	element.Flag = nil
	local divider = Divider.new({ Theme = element._window.Theme })
	divider.Instance.LayoutOrder = container:_nextOrder()
	divider.Instance.Parent = container._holder
	element._maid:GiveTask(divider)
	element.Instance = divider.Instance
	return element
end

return Text
