--[[
	Material 3 Chip. Variants: "Assist", "Filter", "Input", "Suggestion".
	Filter chips toggle Selected on click. Input chips can show a remove (x)
	affordance by passing Removable = true.

	local chip = MD3.Chip.new({ Text = "Extra cheese", Variant = "Filter", Parent = row })
	chip.Toggled:Connect(function(selected) ... end)
	chip.Removed:Connect(function() ... end)
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
local Icons = require(Root.Core.Icons)
local Assets = require(Root.Executor.Assets)

local Chip = {}
Chip.__index = Chip

local HEIGHT = 32

function Chip.new(props)
	props = props or {}
	local self = setmetatable({}, Chip)
	self._maid = Maid.new()
	self._theme = props.Theme or Theme.Default()
	self._variant = props.Variant or "Assist"
	self._selected = props.Selected or false
	self._disabled = props.Disabled or false
	self.Activated = Signal.new()
	self.Toggled = Signal.new()
	self.Removed = Signal.new()

	local chip = Create("TextButton") {
		Name = props.Name or "MD3Chip",
		AutoButtonColor = false,
		Text = "",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, HEIGHT),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder or 0,
	}
	Shape.Corner(Shape.Small, chip)

	local stroke = Create("UIStroke") {
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = chip,
	}
	self._stroke = stroke

	-- Padding + layout live on an inner frame: the state layer and ripples
	-- are parented to the chip itself and must not be laid out.
	local content = Create("Frame") {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = chip,
	}
	Create("UIPadding") {
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		Parent = content,
	}
	Create("UIListLayout") {
		SortOrder = Enum.SortOrder.LayoutOrder, -- the default sorts by Name
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		Parent = content,
	}

	local leadingIcon = nil
	if props.Icon then
		leadingIcon = Create("ImageLabel") {
			Name = "LeadingIcon",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(18, 18),
			Image = Assets.Resolve(props.Icon),
			LayoutOrder = 1,
			Parent = content,
		}
	end
	self._leadingIcon = leadingIcon

	local label = Create("TextLabel") {
		Name = "Label",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Text = props.Text or "",
		LayoutOrder = 2,
		Parent = content,
	}
	Typography.Apply(label, "LabelLarge")
	self._label = label

	local removeButton = nil
	if props.Removable then
		removeButton = Create("TextButton") {
			Name = "Remove",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(18, 18),
			TextScaled = true,
			LayoutOrder = 3,
			Parent = content,
		}
		Icons.Apply(removeButton, "close")
	end
	self._removeButton = removeButton

	self.Instance = chip
	self._stateLayer = StateLayer.new(chip, Color3.new(1, 1, 1), Shape.Small)

	self:_applyTheme()
	self:_bindInput()

	self._maid:GiveTask(self._theme.Changed:Connect(function()
		self:_applyTheme()
	end))

	if props.Parent then
		chip.Parent = props.Parent
	end

	return self
end

function Chip:_applyTheme()
	local c = self._theme.Colors
	local selected = self._selected and self._variant == "Filter"

	local container = selected and c.SecondaryContainer or c.Surface
	local containerTransparency = selected and 0 or 1
	local onColor = selected and c.OnSecondaryContainer or c.OnSurfaceVariant
	local borderColor = selected and container or c.Outline

	if self._disabled then
		container, onColor, borderColor = c.OnSurface, c.OnSurface, c.OnSurface
		containerTransparency = selected and 0.88 or 1
	end

	TweenService:Create(self.Instance, Motion.Standard(Motion.Duration.Short2), {
		BackgroundColor3 = container,
		BackgroundTransparency = containerTransparency,
	}):Play()

	self._label.TextColor3 = onColor
	self._label.TextTransparency = self._disabled and 0.62 or 0
	self._stroke.Color = borderColor
	self._stroke.Transparency = self._disabled and 0.88 or (selected and 1 or 0)

	if self._leadingIcon then
		self._leadingIcon.ImageColor3 = onColor
		self._leadingIcon.ImageTransparency = self._disabled and 0.62 or 0
	end
	if self._removeButton then
		Icons.Apply(self._removeButton, "close")
		self._removeButton.TextColor3 = onColor
		self._removeButton.TextTransparency = self._disabled and 0.62 or 0
	end

	self._stateLayer:SetColor(onColor)
end

function Chip:_bindInput()
	local chip = self.Instance
	self._maid:GiveTask(chip.MouseEnter:Connect(function()
		if not self._disabled then
			self._stateLayer:SetState("Hover", true)
		end
	end))
	self._maid:GiveTask(chip.MouseLeave:Connect(function()
		self._stateLayer:SetState("Hover", false)
		self._stateLayer:SetState("Pressed", false)
	end))
	self._maid:GiveTask(chip.InputBegan:Connect(function(input)
		if not self._disabled and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			self._stateLayer:SetState("Pressed", true)
			Ripple.Emit(chip, input.Position, self._theme.Colors.OnSurfaceVariant)
		end
	end))
	self._maid:GiveTask(chip.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self._stateLayer:SetState("Pressed", false)
		end
	end))
	self._maid:GiveTask(chip.Activated:Connect(function()
		if self._disabled then
			return
		end
		if self._variant == "Filter" then
			self._selected = not self._selected
			self:_applyTheme()
			self.Toggled:Fire(self._selected)
		end
		self.Activated:Fire()
	end))

	if self._removeButton then
		self._maid:GiveTask(self._removeButton.Activated:Connect(function()
			if not self._disabled then
				self.Removed:Fire()
			end
		end))
	end
end

function Chip:SetSelected(selected: boolean)
	self._selected = selected
	self:_applyTheme()
end

function Chip:SetDisabled(disabled: boolean)
	self._disabled = disabled
	self.Instance.Active = not disabled
	self:_applyTheme()
end

function Chip:SetTheme(theme)
	self._theme = theme
	self:_applyTheme()
end

function Chip:Destroy()
	self._stateLayer:Destroy()
	self._maid:Destroy()
	self.Activated:DisconnectAll()
	self.Toggled:DisconnectAll()
	self.Removed:DisconnectAll()
	self.Instance:Destroy()
end

return Chip
