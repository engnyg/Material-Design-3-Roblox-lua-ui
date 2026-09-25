--[[
	Material 3 Top App Bar (small/center-aligned layout).

	local bar = MD3.TopAppBar.new({
		Title = "Settings",
		NavigationIcon = "rbxassetid://...",
		Actions = { { Icon = "rbxassetid://...", OnActivated = function() end } },
		Parent = screen,
	})
]]
local Root = script.Parent.Parent
local Create = require(Root.Util.Create)
local Maid = require(Root.Util.Maid)
local Theme = require(Root.Core.Theme)
local Typography = require(Root.Core.Typography)
local IconButton = require(Root.Components.IconButton)

local TopAppBar = {}
TopAppBar.__index = TopAppBar

local HEIGHT = 64

function TopAppBar.new(props)
	props = props or {}
	local self = setmetatable({}, TopAppBar)
	self._maid = Maid.new()
	self._theme = props.Theme or Theme.Default()
	self._actionButtons = {}

	local root = Create("Frame") {
		Name = props.Name or "MD3TopAppBar",
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, HEIGHT),
		LayoutOrder = props.LayoutOrder or 0,
	}
	Create("UIPadding") {
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
		Parent = root,
	}
	Create("UIListLayout") {
		SortOrder = Enum.SortOrder.LayoutOrder, -- the default sorts by Name
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
		Parent = root,
	}

	if props.NavigationIcon then
		self._navButton = IconButton.new({
			Icon = props.NavigationIcon,
			Theme = self._theme,
			LayoutOrder = 0,
			Parent = root,
		})
		if props.OnNavigate then
			self._navButton.Activated:Connect(props.OnNavigate)
		end
	end

	local title = Create("TextLabel") {
		Name = "Title",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Text = props.Title or "",
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		Parent = root,
	}
	Typography.Apply(title, "TitleLarge")
	self._title = title

	Create("Frame") {
		Name = "Spacer",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		LayoutOrder = 2,
		Parent = root,
	}

	for i, action in ipairs(props.Actions or {}) do
		local btn = IconButton.new({
			Icon = action.Icon,
			Theme = self._theme,
			LayoutOrder = 2 + i,
			Parent = root,
		})
		if action.OnActivated then
			btn.Activated:Connect(action.OnActivated)
		end
		table.insert(self._actionButtons, btn)
	end

	self.Instance = root

	self:_applyTheme()
	self._maid:GiveTask(self._theme.Changed:Connect(function()
		self:_applyTheme()
	end))

	if props.Parent then
		root.Parent = props.Parent
	end

	return self
end

function TopAppBar:_applyTheme()
	self.Instance.BackgroundColor3 = self._theme.Colors.Surface
	self._title.TextColor3 = self._theme.Colors.OnSurface
end

function TopAppBar:SetTitle(text: string)
	self._title.Text = text
end

function TopAppBar:SetTheme(theme)
	self._theme = theme
	self:_applyTheme()
	if self._navButton then
		self._navButton:SetTheme(theme)
	end
	for _, btn in self._actionButtons do
		btn:SetTheme(theme)
	end
end

function TopAppBar:Destroy()
	self._maid:Destroy()
	if self._navButton then
		self._navButton:Destroy()
	end
	for _, btn in self._actionButtons do
		btn:Destroy()
	end
	self.Instance:Destroy()
end

return TopAppBar
