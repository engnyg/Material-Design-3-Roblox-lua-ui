-- A window tab (navigation-drawer item + scrolling page) and its Sections.
-- Both expose the element API from Container (AddToggle, AddSlider, ...).
local TweenService = game:GetService("TweenService")

local Root = script.Parent.Parent
local Create = require(Root.Util.Create)
local Typography = require(Root.Core.Typography)
local Shape = require(Root.Core.Shape)
local Motion = require(Root.Core.Motion)
local StateLayer = require(Root.Core.StateLayer)
local Container = require(script.Parent.Container)
local Base = require(script.Parent.Elements.Base)

--== Section ==--

local Section = {}
Section.__index = Section
Container.extend(Section)

function Section.new(tab, title: string?)
	local self = setmetatable({}, Section)
	self._window = tab._window
	self._tab = tab
	self._order = 0
	self._elements = {}
	local themer = self._window._themer

	local frame = Create("Frame") {
		Name = title or "Section",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = tab:_nextOrder(),
		[1] = Create("UIListLayout") {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		},
	}

	if title and title ~= "" then
		local header = Create("TextLabel") {
			Name = "Header",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 28),
			Text = title,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			LayoutOrder = 0,
			Parent = frame,
			[1] = Create("UIPadding") { PaddingLeft = UDim.new(0, 4), PaddingBottom = UDim.new(0, 2) },
		}
		Typography.Apply(header, "TitleSmall")
		themer:Bind(header, { TextColor3 = "Primary" })
		self._header = header
	end

	frame.Parent = tab._holder
	self.Instance = frame
	self._holder = frame
	return self
end

function Section:SetTitle(text: string)
	if self._header then
		self._header.Text = text
	end
end

function Section:SetVisible(visible: boolean)
	self.Instance.Visible = visible
end

function Section:Destroy()
	for _, element in self._elements do
		element:Destroy()
	end
	self.Instance:Destroy()
end

--== Tab ==--

local Tab = {}
Tab.__index = Tab
Container.extend(Tab)

function Tab.new(window, props)
	if type(props) == "string" then
		props = { Title = props }
	end
	props = props or {}
	local self = setmetatable({}, Tab)
	self._window = window
	self._order = 0
	self._elements = {}
	self._sections = {}
	self.Title = props.Title or props.Name or "Tab"
	local themer = window._themer
	local theme = window.Theme

	-- Navigation drawer item: pill-shaped active indicator, icon + label.
	local button = Create("TextButton") {
		Name = self.Title,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = #window.Tabs + 1,
		Parent = window._navList,
	}
	Shape.Corner(Shape.Full, button)
	local stateLayer = StateLayer.new(button, theme.Colors.OnSurface, Shape.Full)

	local icon = Base.Glyph(themer, props.Icon or "circle", 20, nil, button)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 14, 0.5, 0)
	local hasIcon = props.Icon ~= nil and icon.Visible
	icon.Visible = hasIcon

	local label = Create("TextLabel") {
		Name = "Label",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(hasIcon and 44 or 16, 0),
		Size = UDim2.new(1, hasIcon and -52 or -24, 1, 0),
		Text = self.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = button,
	}
	Typography.Apply(label, "LabelLarge")

	self._button = button
	self._icon = icon
	self._label = label
	self._stateLayer = stateLayer

	local page = Create("ScrollingFrame") {
		Name = self.Title,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		Visible = false,
		Parent = window._pages,
		[1] = Create("UIPadding") {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 16),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		},
		[2] = Create("UIListLayout") {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		},
	}
	themer:Bind(page, { ScrollBarImageColor3 = "Outline" })
	self.Instance = page
	self._holder = page

	window._maid:GiveTask(button.MouseEnter:Connect(function()
		stateLayer:SetState("Hover", true)
	end))
	window._maid:GiveTask(button.MouseLeave:Connect(function()
		stateLayer:SetState("Hover", false)
	end))
	window._maid:GiveTask(button.Activated:Connect(function()
		window:SelectTab(self)
	end))
	window._maid:GiveTask(theme.Changed:Connect(function()
		self:_paint()
	end))

	self:_paint()
	return self
end

function Tab:_paint()
	local c = self._window.Theme.Colors
	local active = self._window.SelectedTab == self
	self._button.BackgroundColor3 = c.SecondaryContainer
	TweenService:Create(self._button, Motion.Standard(Motion.Duration.Short3), {
		BackgroundTransparency = active and 0 or 1,
	}):Play()
	local content = active and c.OnSecondaryContainer or c.OnSurfaceVariant
	self._label.TextColor3 = content
	Base.SetIconColor(self._icon, content)
	self._stateLayer:SetColor(c.OnSurface)
end

function Tab:_setActive(active: boolean)
	local page = self.Instance
	page.Visible = active
	if active then
		page.Position = UDim2.fromOffset(0, 12)
		TweenService:Create(page, Motion.Emphasized(Motion.Duration.Medium2), { Position = UDim2.new() }):Play()
	end
	self:_paint()
end

function Tab:AddSection(title: string?)
	local section = Section.new(self, title)
	table.insert(self._sections, section)
	return section
end
Tab.CreateSection = Tab.AddSection

function Tab:Select()
	self._window:SelectTab(self)
end

function Tab:Destroy()
	for _, section in self._sections do
		section:Destroy()
	end
	for _, element in self._elements do
		element:Destroy()
	end
	self._button:Destroy()
	self.Instance:Destroy()
end

Tab.Section = Section
return Tab
