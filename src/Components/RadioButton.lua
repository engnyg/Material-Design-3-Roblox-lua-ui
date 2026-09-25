--[[
	Material 3 Radio Button. Typically used in a RadioGroup so only one is
	selected at a time — see RadioButton.Group() below.

	local group = MD3.RadioButton.Group({ "a", "b", "c" }, "a", parentFrame)
	group.Changed:Connect(function(value) ... end)
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

local RadioButton = {}
RadioButton.__index = RadioButton

local RING_SIZE = 20
local DOT_SIZE = 10
local HITBOX_SIZE = 40

function RadioButton.new(props)
	props = props or {}
	local self = setmetatable({}, RadioButton)
	self._maid = Maid.new()
	self._theme = props.Theme or Theme.Default()
	self._selected = props.Selected or false
	self._disabled = props.Disabled or false
	self.Activated = Signal.new()

	local hitbox = Create("TextButton") {
		Name = props.Name or "MD3Radio",
		AutoButtonColor = false,
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(HITBOX_SIZE, HITBOX_SIZE),
		LayoutOrder = props.LayoutOrder or 0,
	}
	Shape.Corner(Shape.Full, hitbox)

	local ring = Create("Frame") {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(RING_SIZE, RING_SIZE),
		BackgroundTransparency = 1,
		Parent = hitbox,
	}
	Shape.Corner(Shape.Full, ring)

	local stroke = Create("UIStroke") {
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = ring,
	}
	self._stroke = stroke

	local dot = Create("Frame") {
		Name = "Dot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BorderSizePixel = 0,
		Parent = ring,
	}
	Shape.Corner(Shape.Full, dot)
	self._dot = dot

	self.Instance = hitbox
	self._stateLayer = StateLayer.new(hitbox, Color3.new(1, 1, 1), Shape.Full)

	self:_render(false)
	self:_bindInput()

	self._maid:GiveTask(self._theme.Changed:Connect(function()
		self:_render(true)
	end))

	if props.Parent then
		hitbox.Parent = props.Parent
	end

	return self
end

function RadioButton:_render(animate: boolean)
	local c = self._theme.Colors
	local ringColor = self._selected and (self._disabled and c.OnSurface or c.Primary) or (self._disabled and c.OnSurface or c.OnSurfaceVariant)
	local dotColor = ringColor
	local dotSize = self._selected and DOT_SIZE or 0

	self._stroke.Color = ringColor
	self._stroke.Transparency = self._disabled and 0.62 or 0

	if animate then
		TweenService:Create(self._dot, Motion.Standard(Motion.Duration.Short2), {
			Size = UDim2.fromOffset(dotSize, dotSize),
			BackgroundColor3 = dotColor,
			BackgroundTransparency = self._disabled and 0.62 or 0,
		}):Play()
	else
		self._dot.Size = UDim2.fromOffset(dotSize, dotSize)
		self._dot.BackgroundColor3 = dotColor
		self._dot.BackgroundTransparency = self._disabled and 0.62 or 0
	end

	self._stateLayer:SetColor(self._selected and c.Primary or c.OnSurface)
end

function RadioButton:_bindInput()
	local hitbox = self.Instance
	self._maid:GiveTask(hitbox.MouseEnter:Connect(function()
		if not self._disabled then
			self._stateLayer:SetState("Hover", true)
		end
	end))
	self._maid:GiveTask(hitbox.MouseLeave:Connect(function()
		self._stateLayer:SetState("Hover", false)
		self._stateLayer:SetState("Pressed", false)
	end))
	self._maid:GiveTask(hitbox.InputBegan:Connect(function(input)
		if not self._disabled and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			self._stateLayer:SetState("Pressed", true)
		end
	end))
	self._maid:GiveTask(hitbox.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self._stateLayer:SetState("Pressed", false)
		end
	end))
	self._maid:GiveTask(hitbox.Activated:Connect(function()
		if not self._disabled then
			self.Activated:Fire()
		end
	end))
end

function RadioButton:SetSelected(selected: boolean)
	self._selected = selected
	self:_render(true)
end

function RadioButton:SetDisabled(disabled: boolean)
	self._disabled = disabled
	self.Instance.Active = not disabled
	self:_render(true)
end

function RadioButton:SetTheme(theme)
	self._theme = theme
	self:_render(true)
end

function RadioButton:Destroy()
	self._stateLayer:Destroy()
	self._maid:Destroy()
	self.Activated:DisconnectAll()
	self.Instance:Destroy()
end

-- Convenience: builds a set of radio buttons that behave as a mutually-
-- exclusive group. `options` is an array of { Value = any, Text = string? }.
function RadioButton.Group(options, initialValue, parent, theme)
	local group = {}
	group.Changed = Signal.new()
	group._buttons = {}
	group.Value = initialValue

	for _, option in ipairs(options) do
		local row = Create("Frame") {
			Name = "Option",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = parent,
			[1] = Create("UIListLayout") {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 4),
			},
		}

		local radio = RadioButton.new({
			Theme = theme,
			Selected = option.Value == initialValue,
			Parent = row,
		})

		if option.Text then
			local Typography = require(Root.Core.Typography)
			local label = Create("TextLabel") {
				Name = "Label",
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				Text = option.Text,
				TextColor3 = (theme or Theme.Default()).Colors.OnSurface,
				Parent = row,
			}
			Typography.Apply(label, "BodyLarge")
		end

		radio.Activated:Connect(function()
			group:SetValue(option.Value)
		end)

		table.insert(group._buttons, { radio = radio, value = option.Value, row = row })
	end

	function group:SetValue(value)
		if self.Value == value then
			return
		end
		self.Value = value
		for _, entry in self._buttons do
			entry.radio:SetSelected(entry.value == value)
		end
		self.Changed:Fire(value)
	end

	function group:Destroy()
		for _, entry in self._buttons do
			entry.radio:Destroy()
			entry.row:Destroy()
		end
		self.Changed:DisconnectAll()
	end

	return group
end

return RadioButton
