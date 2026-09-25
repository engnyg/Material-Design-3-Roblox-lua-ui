--[[
	Material 3 Button. Variants: "Filled" (default), "Tonal", "Outlined", "Text", "Elevated".

	MD3.Button.new({
		Text = "Continue",
		Variant = "Filled",
		Theme = myTheme,      -- optional, defaults to the shared Theme.Default()
		Parent = someFrame,
		Disabled = false,
	})
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

local Button = {}
Button.__index = Button

local HEIGHT = 40

local function colorsFor(theme, variant: string)
	local c = theme.Colors
	if variant == "Filled" then
		return { container = c.Primary, label = c.OnPrimary, border = nil, elevation = 0 }
	elseif variant == "Tonal" then
		return { container = c.SecondaryContainer, label = c.OnSecondaryContainer, border = nil, elevation = 0 }
	elseif variant == "Elevated" then
		return { container = c.SurfaceContainerLow, label = c.Primary, border = nil, elevation = 1 }
	elseif variant == "Outlined" then
		return { container = c.Surface, containerTransparency = 1, label = c.Primary, border = c.Outline, elevation = 0 }
	elseif variant == "Text" then
		return { container = c.Surface, containerTransparency = 1, label = c.Primary, border = nil, elevation = 0 }
	end
	error(`Unknown Button variant "{variant}"`)
end

function Button.new(props)
	props = props or {}
	local self = setmetatable({}, Button)
	self._maid = Maid.new()
	self._theme = props.Theme or Theme.Default()
	self._variant = props.Variant or "Filled"
	self._disabled = props.Disabled or false
	self.Activated = Signal.new()

	local button = Create("TextButton") {
		Name = props.Name or "MD3Button",
		AutoButtonColor = false,
		Text = "",
		Size = props.Size or UDim2.new(0, 0, 0, HEIGHT),
		AutomaticSize = props.Size and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder or 0,
		ClipsDescendants = false,
	}
	Shape.Corner(Shape.Full, button)

	local padding = Create("UIPadding") {
		PaddingLeft = UDim.new(0, 24),
		PaddingRight = UDim.new(0, 24),
		Parent = button,
	}
	self._padding = padding

	Create("UIListLayout") {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		Parent = button,
	}

	local icon = nil
	if props.Icon then
		icon = Create("ImageLabel") {
			Name = "Icon",
			BackgroundTransparency = 1,
			Image = props.Icon,
			Size = UDim2.fromOffset(18, 18),
			LayoutOrder = 1,
			Parent = button,
		}
	end
	self._icon = icon

	local label = Create("TextLabel") {
		Name = "Label",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Text = props.Text or "",
		LayoutOrder = 2,
		Parent = button,
	}
	Typography.Apply(label, "LabelLarge")
	self._label = label

	local stroke = Create("UIStroke") {
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = button,
	}
	self._stroke = stroke

	self.Instance = button
	self._stateLayer = StateLayer.new(button, Color3.new(1, 1, 1), Shape.Full)

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

function Button:_applyTheme()
	local colors = colorsFor(self._theme, self._variant)
	local button = self.Instance

	TweenService:Create(button, Motion.Standard(Motion.Duration.Short2), {
		BackgroundColor3 = colors.container,
		BackgroundTransparency = self._disabled and 0.88 or (colors.containerTransparency or 0),
	}):Play()

	self._label.TextColor3 = colors.label
	self._label.TextTransparency = self._disabled and 0.62 or 0
	if self._icon then
		self._icon.ImageColor3 = colors.label
		self._icon.ImageTransparency = self._disabled and 0.62 or 0
	end

	self._stroke.Color = colors.border or colors.label
	self._stroke.Transparency = colors.border and (self._disabled and 0.88 or 0) or 1

	self._stateLayer:SetColor(colors.label)

	if colors.elevation and colors.elevation > 0 and not self._disabled then
		Elevation.Apply(button, colors.elevation, self._theme.Colors.Shadow, Shape.Full)
	else
		Elevation.Remove(button)
	end
end

function Button:_bindInput()
	local button = self.Instance

	self._maid:GiveTask(button.MouseEnter:Connect(function()
		if not self._disabled then
			self._stateLayer:SetState("Hover", true)
		end
	end))
	self._maid:GiveTask(button.MouseLeave:Connect(function()
		self._stateLayer:SetState("Hover", false)
		self._stateLayer:SetState("Pressed", false)
	end))
	self._maid:GiveTask(button.InputBegan:Connect(function(input)
		if self._disabled then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self._stateLayer:SetState("Pressed", true)
			Ripple.Emit(button, input.Position, colorsFor(self._theme, self._variant).label)
		end
	end))
	self._maid:GiveTask(button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self._stateLayer:SetState("Pressed", false)
		end
	end))
	self._maid:GiveTask(button.Activated:Connect(function(...)
		if not self._disabled then
			self.Activated:Fire(...)
		end
	end))
end

function Button:SetText(text: string)
	self._label.Text = text
end

function Button:SetVariant(variant: string)
	self._variant = variant
	self:_applyTheme()
end

function Button:SetDisabled(disabled: boolean)
	self._disabled = disabled
	self.Instance.Active = not disabled
	self:_applyTheme()
end

function Button:SetTheme(theme)
	self._theme = theme
	self:_applyTheme()
end

function Button:Destroy()
	Elevation.Remove(self.Instance)
	self._stateLayer:Destroy()
	self._maid:Destroy()
	self.Activated:DisconnectAll()
	self.Instance:Destroy()
end

return Button
