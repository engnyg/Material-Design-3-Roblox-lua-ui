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
	self.Title = title or ""
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
	-- nil = follow the theme's Icon / IconSelected roles; a role name or a
	-- Color3 pins the icon color (selected or not).
	self._iconColor = props.IconColor
	if props.SectionsAsSubTabs ~= nil then
		self._sectionsAsSubTabs = props.SectionsAsSubTabs
	else
		self._sectionsAsSubTabs = window._sectionsAsSubTabs
	end
	local themer = window._themer
	local theme = window.Theme

	-- Navigation drawer / top-bar tab button
	local hasIcon = props.Icon ~= nil and Base.CanShowIcon(props.Icon)
	local textLen = 0
	for _ in utf8.graphemes(self.Title) do textLen += 1 end
	local btnWidth = math.clamp((hasIcon and 38 or 20) + (textLen * 10) + 18, 80, 160)

	local button = Create("TextButton") {
		Name = self.Title,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, btnWidth, 0, 36),
		LayoutOrder = #window.Tabs + 1,
		ZIndex = 4,
		Parent = window._navList,
	}
	Shape.Corner(Shape.Full, button)
	local stateLayer = StateLayer.new(button, theme.Colors.OnSurface, Shape.Full)

	local icon = Base.Glyph(themer, props.Icon or "circle", 20, nil, button)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 10, 0.5, 0)
	icon.ZIndex = 5
	-- Reserve room for the icon even if it's still waiting for the icon images.
	if not hasIcon then
		icon.Visible = false
	end

	local label = Create("TextLabel") {
		Name = "Label",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, hasIcon and 34 or 10, 0, 0),
		Size = UDim2.new(1, hasIcon and -40 or -20, 1, 0),
		Text = self.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 5,
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
	local theme = self._window.Theme
	local c = theme.Colors
	local function alpha(role)
		return theme:GetTransparency(role) or 0
	end
	local active = self._window.SelectedTab == self
	self._button.BackgroundTransparency = 1
	local textRole = if active then "OnSecondaryContainer" else "OnSurfaceVariant"
	self._label.TextColor3 = c[textRole]
	self._label.TextTransparency = alpha(textRole)
	local iconColor = self._iconColor
	if typeof(iconColor) == "Color3" then
		Base.SetIconColor(self._icon, iconColor)
	elseif type(iconColor) == "string" and c[iconColor] then
		Base.SetIconColor(self._icon, c[iconColor], alpha(iconColor))
	else
		local iconRole = if active then "IconSelected" else "Icon"
		Base.SetIconColor(self._icon, c[iconRole], alpha(iconRole))
	end
	self._stateLayer:SetColor(c.OnSurface)
end

function Tab:_setActive(active: boolean)
	local page = self.Instance
	page.Visible = active
	if active then
		page.Position = UDim2.fromOffset(0, 12)
		TweenService:Create(page, Motion.Emphasized(Motion.Duration.Medium2), { Position = UDim2.new() }):Play()
		if self._window._slideToTab then
			self._window:_slideToTab(self, false)
		end
	end
	self:_paint()
end

-- Creates a Section in `holder` (the page, or a sub-tab column).
function Tab:_addSectionIn(holder, title: string?, subName: string?)
	local origHolder = self._holder
	self._holder = holder
	local section = Section.new(self, title)
	self._holder = origHolder
	section._subTab = subName
	table.insert(self._sections, section)
	if self._window and self._window._registerSearchable then
		local path = { self.Title }
		if subName then
			table.insert(path, subName)
		end
		if not subName or (title or "Section") ~= subName then
			table.insert(path, title or "Section")
		end
		self._window:_registerSearchable({
			name = title or "Section",
			path = table.concat(path, " > "),
			tab = self,
			subTab = subName,
			target = section.Instance,
		})
	end
	return section
end

-- With SectionsAsSubTabs (on the tab or the window) every section gets its
-- own sub-tab named after it; sections sharing a title share the sub-tab.
function Tab:AddSection(title: string?)
	if self._sectionsAsSubTabs then
		local sub = self:AddSubTab(title or "Section", { Columns = 1 })
		local section = sub:AddSection(title)
		if section._header then
			section._header.Visible = false -- the sub-tab button already shows it
		end
		return section
	end
	return self:_addSectionIn(self._holder, title, nil)
end
Tab.CreateSection = Tab.AddSection

local function paintSubButton(theme, btn, selected)
	local c = theme.Colors
	local stroke = btn:FindFirstChildOfClass("UIStroke")
	if selected then
		btn.BackgroundColor3 = c.SecondaryContainer or Color3.fromRGB(74, 68, 88)
		btn.TextColor3 = c.OnSecondaryContainer or Color3.fromRGB(232, 222, 248)
		if stroke then
			stroke.Transparency = 0.2
			stroke.Color = c.Primary or Color3.fromRGB(208, 188, 255)
			stroke.Thickness = 1.5
		end
	else
		btn.BackgroundColor3 = c.SurfaceContainerHigh or Color3.fromRGB(36, 33, 43)
		btn.TextColor3 = c.OnSurfaceVariant or Color3.fromRGB(202, 196, 208)
		if stroke then
			stroke.Transparency = 0.6
			stroke.Color = c.OutlineVariant or Color3.fromRGB(73, 69, 79)
			stroke.Thickness = 1
		end
	end
end

function Tab:_paintSubTabs()
	local theme = self._window.Theme
	for i, sub in ipairs(self._subTabs) do
		local selected = i == self._selectedSub
		sub.Holder.Visible = selected
		paintSubButton(theme, sub.Button, selected)
	end
end

-- Shows a sub-tab, by name or index.
function Tab:SelectSubTab(which)
	local subs = self._subTabs
	if not subs then
		return
	end
	local index = which
	if type(which) ~= "number" then
		index = table.find(subs, subs[which])
	end
	if index and subs[index] then
		self._selectedSub = index
		self:_paintSubTabs()
	end
end

function Tab:_ensureSubNav()
	if self._subNav then
		return
	end
	self._subNav = Create("ScrollingFrame") {
		Name = "SubNavBar",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 42),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		LayoutOrder = 0,
		Parent = self.Instance,
		[1] = Create("UIListLayout") {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		},
		[2] = Create("UIPadding") {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
		},
	}
	self._subTabs = {} -- array of sub-tabs, also keyed by name
	self._window._maid:GiveTask(self._window.Theme.Changed:Connect(function()
		self:_paintSubTabs()
	end))
end

-- Adds one sub-tab (a button in the sub-nav bar + its own content area).
-- opts.Columns = 1 gives a single full-width column; the default is two
-- columns (AddLeftSection / AddRightSection). Adding an existing name
-- returns that sub-tab.
function Tab:AddSubTab(name: string, opts)
	opts = opts or {}
	self:_ensureSubNav()
	local subs = self._subTabs
	if subs[name] then
		return subs[name]
	end
	local index = #subs + 1
	local themer = self._window._themer
	local twoColumns = opts.Columns ~= 1

	local holder = Create("Frame") {
		Name = "SubCategory_" .. name,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = index,
		Visible = false,
		Parent = self.Instance,
	}

	local function column(colName, size, position)
		return Create("Frame") {
			Name = colName,
			BackgroundTransparency = 1,
			Size = size,
			Position = position,
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = holder,
			[1] = Create("UIListLayout") {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			},
		}
	end

	local leftCol, rightCol, divider
	if twoColumns then
		leftCol = column("LeftCol", UDim2.new(0.5, -8, 0, 0), UDim2.new())
		divider = Create("Frame") {
			Name = "DividerLine",
			Size = UDim2.new(0, 1, 1, 0),
			Position = UDim2.new(0.5, 0, 0, 0),
			BackgroundColor3 = self._window.Theme.Colors.OutlineVariant,
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = holder,
		}
		themer:Bind(divider, { BackgroundColor3 = "OutlineVariant" })
		rightCol = column("RightCol", UDim2.new(0.5, -8, 0, 0), UDim2.new(0.5, 8, 0, 0))
	else
		leftCol = column("Column", UDim2.new(1, 0, 0, 0), UDim2.new())
		rightCol = leftCol
	end

	local charCount = 0
	for _ in utf8.graphemes(name) do charCount += 1 end
	local btn = Create("TextButton") {
		Name = "SubBtn_" .. name,
		AutoButtonColor = false,
		Text = name,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		Size = UDim2.new(0, math.clamp(charCount * 9 + 32, 84, 160), 0, 32),
		LayoutOrder = index,
		BorderSizePixel = 0,
		Parent = self._subNav,
	}
	Shape.Corner(Shape.Full, btn)
	Create("UIStroke") {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 1,
		Parent = btn,
	}
	self._window._maid:GiveTask(btn.Activated:Connect(function()
		self:SelectSubTab(index)
	end))

	local tab = self
	local sub = {
		Name = name,
		Holder = holder,
		Left = leftCol,
		Right = rightCol,
		Divider = divider,
		Button = btn,
	}
	function sub.Select()
		tab:SelectSubTab(index)
	end
	function sub:AddLeftSection(title)
		return tab:_addSectionIn(leftCol, title, name)
	end
	function sub:AddRightSection(title)
		return tab:_addSectionIn(rightCol, title, name)
	end
	function sub:AddSection(title, side)
		if side == "Right" or side == "right" then
			return self:AddRightSection(title)
		end
		return self:AddLeftSection(title)
	end

	subs[name] = sub
	table.insert(subs, sub)
	if index == 1 then
		self._selectedSub = 1
	end
	self:_paintSubTabs()
	return sub
end

function Tab:AddSubTabs(names: { string } | string, ...)
	local list = if type(names) == "table" then names else { names, ... }
	for _, name in ipairs(list) do
		self:AddSubTab(name)
	end
	return self._subTabs
end
Tab.CreateSubTabs = Tab.AddSubTabs

-- Pins the tab icon's color (theme role name or Color3); nil follows the theme.
function Tab:SetIconColor(color)
	self._iconColor = color
	self:_paint()
end

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
