--[[
	Material 3 Icon Button. Variants: "Standard", "Filled", "Tonal", "Outlined".
	Optionally toggleable: pass Toggleable = true, then use :SetSelected()/:GetSelected()
	and listen to .Toggled(selected).

	MD3.IconButton.new({ Icon = "rbxassetid://...", Variant = "Standard", Parent = bar })
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
local Assets = require(Root.Executor.Assets)

local IconButton = {}
IconButton.__index = IconButton

local SIZE = 40

local function colorsFor(theme, variant, selected, disabled)
	local c = theme.Colors
	if disabled then
		return { container = c.OnSurface, containerTransparency = variant == "Standard" and 1 or 0.88, icon = c.OnSurface, iconTransparency = 0.62, border = variant == "Outlined" and c.OnSurface or nil, borderTransparency = 0.88 }
	end

	if selected then
		return { container = c.Primary, containerTransparency = 0, icon = c.OnPrimary, iconTransparency = 0 }
	end

	if variant == "Filled" then
		return { container = c.SurfaceContainerHighest, containerTransparency = 0, icon = c.Primary, iconTransparency = 0 }
	elseif variant == "Tonal" then
		return { container = c.SecondaryContainer, containerTransparency = 0, icon = c.OnSecondaryContainer, iconTransparency = 0 }
	elseif variant == "Outlined" then
		return { container = c.Surface, containerTransparency = 1, icon = c.OnSurfaceVariant, iconTransparency = 0, border = c.Outline, borderTransparency = 0 }
	end
	return { container = c.Surface, containerTransparency = 1, icon = c.OnSurfaceVariant, iconTransparency = 0 }
end

function IconButton.new(props)
	props = props or {}
	local self = setmetatable({}, IconButton)
	self._maid = Maid.new()
	self._theme = props.Theme or Theme.Default()
	self._variant = props.Variant or "Standard"
	self._disabled = props.Disabled or false
	self._selected = props.Selected or false
	self._toggleable = props.Toggleable or false
	self.Activated = Signal.new()
	self.Toggled = Signal.new()

	local button = Create("TextButton") {
		Name = props.Name or "MD3IconButton",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromOffset(SIZE, SIZE),
		LayoutOrder = props.LayoutOrder or 0,
	}
	Shape.Corner(Shape.Full, button)

	local stroke = Create("UIStroke") {
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = button,
	}
	self._stroke = stroke

	local icon = Create("ImageLabel") {
		Name = "Icon",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(24, 24),
		Image = Assets.Resolve(props.Icon),
		Parent = button,
	}
	self._icon = icon

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

function IconButton:_applyTheme()
	local colors = colorsFor(self._theme, self._variant, self._selected, self._disabled)
	local tweenInfo = Motion.Standard(Motion.Duration.Short2)

	TweenService:Create(self.Instance, tweenInfo, {
		BackgroundColor3 = colors.container,
		BackgroundTransparency = colors.containerTransparency,
	}):Play()
	TweenService:Create(self._icon, tweenInfo, {
		ImageColor3 = colors.icon,
		ImageTransparency = colors.iconTransparency,
	}):Play()

	self._stroke.Color = colors.border or colors.icon
	self._stroke.Transparency = colors.border and (colors.borderTransparency or 0) or 1
	self._stateLayer:SetColor(colors.icon)
end

function IconButton:_bindInput()
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
			Ripple.Emit(button, input.Position, colorsFor(self._theme, self._variant, self._selected, false).icon)
		end
	end))
	self._maid:GiveTask(button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self._stateLayer:SetState("Pressed", false)
		end
	end))
	self._maid:GiveTask(button.Activated:Connect(function(...)
		if self._disabled then
			return
		end
		if self._toggleable then
			self:SetSelected(not self._selected)
		end
		self.Activated:Fire(...)
	end))
end

function IconButton:SetSelected(selected: boolean)
	self._selected = selected
	self:_applyTheme()
	self.Toggled:Fire(selected)
end

function IconButton:GetSelected(): boolean
	return self._selected
end

function IconButton:SetDisabled(disabled: boolean)
	self._disabled = disabled
	self.Instance.Active = not disabled
	self:_applyTheme()
end

function IconButton:SetIcon(image: string)
	self._icon.Image = Assets.Resolve(image)
end

function IconButton:SetTheme(theme)
	self._theme = theme
	self:_applyTheme()
end

function IconButton:Destroy()
	self._stateLayer:Destroy()
	self._maid:Destroy()
	self.Activated:DisconnectAll()
	self.Toggled:DisconnectAll()
	self.Instance:Destroy()
end

return IconButton
