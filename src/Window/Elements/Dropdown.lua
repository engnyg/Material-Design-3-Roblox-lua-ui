--[[
	Tab:AddDropdown({
		Title = "Weapon",
		Options = { "Sword", "Bow", "Staff" },
		Default = "Sword",          -- Multi: a list, e.g. { "Sword", "Bow" }
		Multi = false,
		Searchable = nil,           -- defaults to true when there are > 8 options
		Flag = "Weapon",
		Callback = function(value) end, -- Multi: receives a list
	})

	dropdown:SetOptions({ ... })   -- replace the option list (e.g. player names)
]]
local TweenService = game:GetService("TweenService")

local Root = script.Parent.Parent.Parent
local Base = require(script.Parent.Base)
local Create = require(Root.Util.Create)
local Typography = require(Root.Core.Typography)
local Shape = require(Root.Core.Shape)
local Motion = require(Root.Core.Motion)
local Icons = require(Root.Core.Icons)

local ITEM_HEIGHT = 32
local MAX_LIST_HEIGHT = 6 * (ITEM_HEIGHT + 2)

return function(container, props)
	local element = Base.Element(container, props, "Dropdown")
	local window = element._window
	local themer = window._themer
	local theme = window.Theme
	local multi = props.Multi == true or props.MultipleOptions == true

	local options = {}
	local items = {} -- option -> { Button, Label, Check }
	local open = false

	local function normalize(value)
		if multi then
			local list = {}
			if type(value) == "table" then
				for key, v in value do
					-- accept both { "A", "B" } and { A = true, B = true }
					if type(key) == "number" then
						table.insert(list, v)
					elseif v == true then
						table.insert(list, key)
					end
				end
			elseif value ~= nil then
				list = { value }
			end
			return list
		end
		if type(value) == "table" then
			return value[1]
		end
		return value
	end

	local function isSelected(option)
		if multi then
			return table.find(element.Value, option) ~= nil
		end
		return element.Value == option
	end

	local function copyValue()
		return multi and table.clone(element.Value) or element.Value
	end

	element.Value = normalize(props.Default or props.Value or props.CurrentOption)

	local row = Base.Row(element, props, { ControlWidth = 170, ControlHeight = 32 })

	local field = Base.Field(themer, "TextButton", row.Control, UDim2.fromScale(1, 1))
	local fieldLabel = Create("TextLabel") {
		Name = "Value",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -40, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = field,
	}
	Typography.Apply(fieldLabel, "BodyMedium")

	local arrow = Base.Glyph(themer, "expand_more", 20, "Icon", field)
	arrow.AnchorPoint = Vector2.new(1, 0.5)
	arrow.Position = UDim2.new(1, -8, 0.5, 0)

	-- Inline menu under the header (inline instead of a floating popup so it
	-- scrolls with the page and never gets clipped by the window).
	local panel = row.Extra(false)
	Create("UIListLayout") {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = panel,
	}

	local search = nil
	local searchable = props.Searchable
	if searchable == nil then
		searchable = #(props.Options or props.Values or {}) > 8
	end
	if searchable then
		search = Base.Field(themer, "TextBox", panel, UDim2.new(1, 0, 0, 32))
		search.LayoutOrder = 1
		search.ClearTextOnFocus = false
		search.PlaceholderText = "Search..."
		search.TextXAlignment = Enum.TextXAlignment.Left
		Typography.Apply(search, "BodyMedium")
		themer:Bind(search, { TextColor3 = "OnSurface", PlaceholderColor3 = "OnSurfaceVariant" })
		Create("UIPadding") { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = search }
	end

	local list = Create("ScrollingFrame") {
		Name = "Options",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		LayoutOrder = 2,
		Parent = panel,
		[1] = Create("UIListLayout") {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		},
	}
	themer:Bind(list, { ScrollBarImageColor3 = "Outline" })

	local function displayText()
		if multi then
			return #element.Value > 0 and table.concat(element.Value, ", ") or (props.Placeholder or "None")
		end
		return element.Value ~= nil and tostring(element.Value) or (props.Placeholder or "Select...")
	end

	local function paint()
		local c = theme.Colors
		fieldLabel.Text = displayText()
		fieldLabel.TextColor3 = (multi and #element.Value > 0 or not multi and element.Value ~= nil) and c.OnSurface
			or c.OnSurfaceVariant
		for option, item in items do
			local selected = isSelected(option)
			item.Button.BackgroundColor3 = c.SecondaryContainer
			item.Button.BackgroundTransparency = selected and 0 or 1
			item.Label.TextColor3 = selected and c.OnSecondaryContainer or c.OnSurface
			item.Check.TextColor3 = c.OnSecondaryContainer
			item.Check.Visible = selected and Icons.CanRender("check")
		end
	end

	local function layoutList()
		local query = search and search.Text:lower() or ""
		local shown = 0
		for option, item in items do
			local visible = query == "" or tostring(option):lower():find(query, 1, true) ~= nil
			item.Button.Visible = visible
			if visible then
				shown += 1
			end
		end
		list.Size = UDim2.new(1, 0, 0, math.min(shown * (ITEM_HEIGHT + 2), MAX_LIST_HEIGHT))
	end

	local function select(option)
		if multi then
			local index = table.find(element.Value, option)
			if index then
				table.remove(element.Value, index)
			else
				table.insert(element.Value, option)
			end
		else
			element.Value = option
		end
		paint()
		element:_emit(copyValue())
	end

	local function setOpen(value: boolean)
		open = value
		panel.Visible = value
		TweenService:Create(arrow, Motion.Standard(Motion.Duration.Short3), { Rotation = value and 180 or 0 }):Play()
		if value then
			layoutList()
		end
	end

	local function buildItems()
		for _, item in items do
			item.Button:Destroy()
		end
		table.clear(items)
		for index, option in options do
			local item = Create("TextButton") {
				Name = tostring(option),
				AutoButtonColor = false,
				Text = "",
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, ITEM_HEIGHT),
				LayoutOrder = index,
				Parent = list,
			}
			Shape.Corner(Shape.Small, item)
			local label = Create("TextLabel") {
				Name = "Label",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -44, 1, 0),
				Text = tostring(option),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = item,
			}
			Typography.Apply(label, "BodyMedium")
			local check = Base.Glyph(themer, "check", 18, nil, item)
			check.AnchorPoint = Vector2.new(1, 0.5)
			check.Position = UDim2.new(1, -10, 0.5, 0)

			item.Activated:Connect(function()
				select(option)
				if not multi then
					setOpen(false)
				end
			end)
			items[option] = { Button = item, Label = label, Check = check }
		end
		paint()
		if open then
			layoutList()
		end
	end

	element._normalize = normalize
	element._render = paint

	-- Replaces the option list. Selections that no longer exist are dropped.
	function element:SetOptions(newOptions)
		options = table.clone(newOptions or {})
		if multi then
			for i = #self.Value, 1, -1 do
				if not table.find(options, self.Value[i]) then
					table.remove(self.Value, i)
				end
			end
		elseif self.Value ~= nil and not table.find(options, self.Value) then
			self.Value = nil
		end
		buildItems()
	end
	element.Refresh = element.SetOptions

	function element:GetOptions()
		return table.clone(options)
	end

	function element:Open()
		setOpen(true)
	end

	function element:Close()
		setOpen(false)
	end

	element._maid:GiveTask(field.Activated:Connect(function()
		setOpen(not open)
	end))
	if search then
		element._maid:GiveTask(search:GetPropertyChangedSignal("Text"):Connect(layoutList))
	end
	element._maid:GiveTask(theme.Changed:Connect(paint))

	options = table.clone(props.Options or props.Values or {})
	buildItems()

	return Base.Finish(element)
end
