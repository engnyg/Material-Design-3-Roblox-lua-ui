--[[
	Material 3 Navigation Bar (bottom bar with 3-5 destinations).

	local nav = MD3.NavigationBar.new({
		Destinations = {
			{ Icon = "rbxassetid://...", Label = "Home" },
			{ Icon = "rbxassetid://...", Label = "Search" },
			{ Icon = "rbxassetid://...", Label = "Profile" },
		},
		Selected = 1,
		Parent = screen,
	})
	nav.Changed:Connect(function(index) ... end)
]]
local TweenService = game:GetService("TweenService")

local Root = script.Parent.Parent
local Create = require(Root.Util.Create)
local Maid = require(Root.Util.Maid)
local Signal = require(Root.Util.Signal)
local Theme = require(Root.Core.Theme)
local Typography = require(Root.Core.Typography)
local Shape = require(Root.Core.Shape)
local Motion = require(Root.Core.Motion)
local StateLayer = require(Root.Core.StateLayer)
local Assets = require(Root.Executor.Assets)

local NavigationBar = {}
NavigationBar.__index = NavigationBar

local HEIGHT = 80
local INDICATOR_SIZE = UDim2.fromOffset(64, 32)

function NavigationBar.new(props)
	props = props or {}
	local self = setmetatable({}, NavigationBar)
	self._maid = Maid.new()
	self._theme = props.Theme or Theme.Default()
	self._items = {}
	self._selected = props.Selected or 1
	self.Changed = Signal.new()

	local root = Create("Frame") {
		Name = props.Name or "MD3NavigationBar",
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, HEIGHT),
		LayoutOrder = props.LayoutOrder or 0,
	}
	Create("UIListLayout") {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = root,
	}

	for i, dest in ipairs(props.Destinations or {}) do
		local item = Create("TextButton") {
			Name = "Item" .. i,
			AutoButtonColor = false,
			Text = "",
			BackgroundTransparency = 1,
			Size = UDim2.new(1 / math.max(#props.Destinations, 1), 0, 1, 0),
			LayoutOrder = i,
			Parent = root,
		}

		local content = Create("Frame") {
			Name = "Content",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(0, 64, 0, 0),
			Parent = item,
		}
		Create("UIListLayout") {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 4),
			Parent = content,
		}

		local indicator = Create("Frame") {
			Name = "Indicator",
			Size = INDICATOR_SIZE,
			BorderSizePixel = 0,
			LayoutOrder = 0,
			Parent = content,
		}
		Shape.Corner(Shape.Full, indicator)
		local stateLayer = StateLayer.new(indicator, Color3.new(1, 1, 1), Shape.Full)

		local icon = Create("ImageLabel") {
			Name = "Icon",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(24, 24),
			Image = Assets.Resolve(dest.Icon),
			Parent = indicator,
		}

		local label = Create("TextLabel") {
			Name = "Label",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 0, 16),
			Text = dest.Label or "",
			LayoutOrder = 1,
			Parent = content,
		}
		Typography.Apply(label, "LabelMedium")

		local entry = { button = item, indicator = indicator, icon = icon, label = label, stateLayer = stateLayer }
		table.insert(self._items, entry)

		self._maid:GiveTask(item.MouseEnter:Connect(function()
			stateLayer:SetState("Hover", true)
		end))
		self._maid:GiveTask(item.MouseLeave:Connect(function()
			stateLayer:SetState("Hover", false)
			stateLayer:SetState("Pressed", false)
		end))
		self._maid:GiveTask(item.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				stateLayer:SetState("Pressed", true)
			end
		end))
		self._maid:GiveTask(item.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				stateLayer:SetState("Pressed", false)
			end
		end))
		self._maid:GiveTask(item.Activated:Connect(function()
			self:SetSelected(i)
		end))
	end

	self.Instance = root

	self:_render(false)
	self._maid:GiveTask(self._theme.Changed:Connect(function()
		self:_render(true)
	end))

	if props.Parent then
		root.Parent = props.Parent
	end

	return self
end

function NavigationBar:_render(animate: boolean)
	local c = self._theme.Colors
	self.Instance.BackgroundColor3 = c.SurfaceContainer

	for i, entry in ipairs(self._items) do
		local selected = i == self._selected
		local indicatorColor = selected and c.SecondaryContainer or c.SurfaceContainer
		local indicatorTransparency = selected and 0 or 1
		local iconColor = selected and c.OnSecondaryContainer or c.OnSurfaceVariant
		local labelColor = selected and c.OnSurface or c.OnSurfaceVariant

		local apply = animate and function(inst, p) TweenService:Create(inst, Motion.Standard(Motion.Duration.Short2), p):Play() end
			or function(inst, p) for k, v in pairs(p) do inst[k] = v end end

		apply(entry.indicator, { BackgroundColor3 = indicatorColor, BackgroundTransparency = indicatorTransparency })
		apply(entry.icon, { ImageColor3 = iconColor })
		apply(entry.label, { TextColor3 = labelColor })
		entry.stateLayer:SetColor(c.OnSurface)
	end
end

function NavigationBar:SetSelected(index: number)
	if self._selected == index then
		return
	end
	self._selected = index
	self:_render(true)
	self.Changed:Fire(index)
end

function NavigationBar:GetSelected(): number
	return self._selected
end

function NavigationBar:SetTheme(theme)
	self._theme = theme
	self:_render(true)
end

function NavigationBar:Destroy()
	for _, entry in self._items do
		entry.stateLayer:Destroy()
	end
	self._maid:Destroy()
	self.Changed:DisconnectAll()
	self.Instance:Destroy()
end

return NavigationBar
