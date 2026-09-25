--[[
	Material 3 Floating Action Button. Sizes: "Small" (40), "Standard" (56), "Large" (96).
	Set Extended = true + Text to get the pill-shaped extended FAB with a label.

	MD3.FAB.new({ Icon = "rbxassetid://...", Size = "Standard", Parent = screen })
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
local Ripple = require(Root.Core.Ripple)
local Elevation = require(Root.Core.Elevation)

local FAB = {}
FAB.__index = FAB

local SIZES = { Small = 40, Standard = 56, Large = 96 }
local ICON_SIZES = { Small = 24, Standard = 24, Large = 36 }
local RADII = { Small = UDim.new(0, 12), Standard = UDim.new(0, 16), Large = UDim.new(0, 28) }

function FAB.new(props)
	props = props or {}
	local self = setmetatable({}, FAB)
	self._maid = Maid.new()
	self._theme = props.Theme or Theme.Default()
	self._size = props.Size or "Standard"
	self._color = props.Color or "PrimaryContainer" -- or "Surface" / "Secondary" / "Tertiary"
	self._extended = props.Extended or false
	self.Activated = Signal.new()

	local dim = SIZES[self._size]
	local radius = RADII[self._size]

	local button = Create("TextButton") {
		Name = props.Name or "MD3FAB",
		AutoButtonColor = false,
		Text = "",
		AutomaticSize = self._extended and Enum.AutomaticSize.X or Enum.AutomaticSize.None,
		Size = self._extended and UDim2.new(0, 0, 0, dim) or UDim2.fromOffset(dim, dim),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder or 0,
	}
	Shape.Corner(radius, button)

	Create("UIListLayout") {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 12),
		Parent = button,
	}

	if self._extended then
		Create("UIPadding") {
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 20),
			Parent = button,
		}
	end

	local icon = Create("ImageLabel") {
		Name = "Icon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(ICON_SIZES[self._size], ICON_SIZES[self._size]),
		Image = props.Icon or "",
		LayoutOrder = 1,
		Parent = button,
	}
	self._icon = icon

	local label = nil
	if self._extended then
		label = Create("TextLabel") {
			Name = "Label",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			Text = props.Text or "",
			LayoutOrder = 2,
			Parent = button,
		}
		Typography.Apply(label, "LabelLarge")
	end
	self._label = label

	self.Instance = button
	self._stateLayer = StateLayer.new(button, Color3.new(1, 1, 1), radius)

	self:_applyTheme()
	self:_bindInput()

	self._maid:GiveTask(self._theme.Changed:Connect(function()
		self:_applyTheme()
	end))

	if props.Parent then
		button.Parent = props.Parent
	end

	return self
end

function FAB:_applyTheme()
	local c = self._theme.Colors
	local container = c[self._color] or c.PrimaryContainer
	local onContainerKey = "On" .. self._color
	local onContainer = c[onContainerKey] or c.OnPrimaryContainer

	TweenService:Create(self.Instance, Motion.Standard(Motion.Duration.Short2), {
		BackgroundColor3 = container,
	}):Play()
	self._icon.ImageColor3 = onContainer
	if self._label then
		self._label.TextColor3 = onContainer
	end
	self._stateLayer:SetColor(onContainer)
	Elevation.Apply(self.Instance, 3, c.Shadow, RADII[self._size])
end

function FAB:_bindInput()
	local button = self.Instance
	self._maid:GiveTask(button.MouseEnter:Connect(function()
		self._stateLayer:SetState("Hover", true)
		Elevation.Apply(button, 4, self._theme.Colors.Shadow, RADII[self._size])
	end))
	self._maid:GiveTask(button.MouseLeave:Connect(function()
		self._stateLayer:SetState("Hover", false)
		self._stateLayer:SetState("Pressed", false)
		Elevation.Apply(button, 3, self._theme.Colors.Shadow, RADII[self._size])
	end))
	self._maid:GiveTask(button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self._stateLayer:SetState("Pressed", true)
			local onContainer = self._theme.Colors["On" .. self._color] or self._theme.Colors.OnPrimaryContainer
			Ripple.Emit(button, input.Position, onContainer)
		end
	end))
	self._maid:GiveTask(button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self._stateLayer:SetState("Pressed", false)
		end
	end))
	self._maid:GiveTask(button.Activated:Connect(function(...)
		self.Activated:Fire(...)
	end))
end

function FAB:SetTheme(theme)
	self._theme = theme
	self:_applyTheme()
end

function FAB:Destroy()
	Elevation.Remove(self.Instance)
	self._stateLayer:Destroy()
	self._maid:Destroy()
	self.Activated:DisconnectAll()
	self.Instance:Destroy()
end

return FAB
