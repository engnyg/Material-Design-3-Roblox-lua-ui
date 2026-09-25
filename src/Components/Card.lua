--[[
	Material 3 Card. Variants: "Elevated", "Filled", "Outlined".
	Cards are plain containers (Size/AutomaticSize up to the caller) with an
	optional content UIListLayout + UIPadding for convenience.

	local card = MD3.Card.new({ Variant = "Elevated", Parent = screen, Size = UDim2.fromOffset(300, 160) })
	someChild.Parent = card.Instance
]]
local TweenService = game:GetService("TweenService")

local Root = script.Parent.Parent
local Create = require(Root.Util.Create)
local Maid = require(Root.Util.Maid)
local Signal = require(Root.Util.Signal)
local Theme = require(Root.Core.Theme)
local Shape = require(Root.Core.Shape)
local Motion = require(Root.Core.Motion)
local StateLayer = require(Root.Core.StateLayer)
local Ripple = require(Root.Core.Ripple)
local Elevation = require(Root.Core.Elevation)

local Card = {}
Card.__index = Card

local function colorsFor(theme, variant)
	local c = theme.Colors
	if variant == "Filled" then
		return { container = c.SurfaceContainerHighest, border = nil, elevation = 0 }
	elseif variant == "Outlined" then
		return { container = c.Surface, border = c.OutlineVariant, elevation = 0 }
	end
	return { container = c.SurfaceContainerLow, border = nil, elevation = 1 } -- Elevated
end

function Card.new(props)
	props = props or {}
	local self = setmetatable({}, Card)
	self._maid = Maid.new()
	self._theme = props.Theme or Theme.Default()
	self._variant = props.Variant or "Elevated"
	self._interactive = props.Interactive or false
	self.Activated = Signal.new()

	local className = self._interactive and "TextButton" or "Frame"
	local card = Create(className) {
		Name = props.Name or "MD3Card",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromOffset(280, 160),
		LayoutOrder = props.LayoutOrder or 0,
		ClipsDescendants = props.ClipsDescendants ~= false,
	}
	if self._interactive then
		card.AutoButtonColor = false
		card.Text = ""
	end
	Shape.Corner(Shape.Medium, card)

	local stroke = Create("UIStroke") {
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = card,
	}
	self._stroke = stroke

	Create("UIPadding") {
		PaddingTop = UDim.new(0, 16),
		PaddingBottom = UDim.new(0, 16),
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
		Parent = card,
	}

	if props.Layout ~= false then
		Create("UIListLayout") {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = card,
		}
	end

	self.Instance = card

	if self._interactive then
		self._stateLayer = StateLayer.new(card, Color3.new(1, 1, 1), Shape.Medium)
		self:_bindInput()
	end

	self:_applyTheme()

	self._maid:GiveTask(self._theme.Changed:Connect(function()
		self:_applyTheme()
	end))

	if props.Parent then
		card.Parent = props.Parent
	end

	return self
end

function Card:_applyTheme()
	local colors = colorsFor(self._theme, self._variant)
	TweenService:Create(self.Instance, Motion.Standard(Motion.Duration.Short2), {
		BackgroundColor3 = colors.container,
	}):Play()

	self._stroke.Color = colors.border or colors.container
	self._stroke.Transparency = colors.border and 0 or 1

	if colors.elevation > 0 then
		Elevation.Apply(self.Instance, colors.elevation, self._theme.Colors.Shadow, Shape.Medium)
	else
		Elevation.Remove(self.Instance)
	end

	if self._stateLayer then
		self._stateLayer:SetColor(self._theme.Colors.OnSurface)
	end
end

function Card:_bindInput()
	local card = self.Instance
	self._maid:GiveTask(card.MouseEnter:Connect(function()
		self._stateLayer:SetState("Hover", true)
	end))
	self._maid:GiveTask(card.MouseLeave:Connect(function()
		self._stateLayer:SetState("Hover", false)
		self._stateLayer:SetState("Pressed", false)
	end))
	self._maid:GiveTask(card.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self._stateLayer:SetState("Pressed", true)
			Ripple.Emit(card, input.Position, self._theme.Colors.OnSurface)
		end
	end))
	self._maid:GiveTask(card.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self._stateLayer:SetState("Pressed", false)
		end
	end))
	self._maid:GiveTask(card.Activated:Connect(function(...)
		self.Activated:Fire(...)
	end))
end

function Card:SetTheme(theme)
	self._theme = theme
	self:_applyTheme()
end

function Card:Destroy()
	Elevation.Remove(self.Instance)
	if self._stateLayer then
		self._stateLayer:Destroy()
	end
	self._maid:Destroy()
	self.Activated:DisconnectAll()
	self.Instance:Destroy()
end

return Card
