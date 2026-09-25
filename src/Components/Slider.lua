--[[
	Material 3 Slider (continuous or stepped).

	local slider = MD3.Slider.new({ Min = 0, Max = 100, Value = 50, Step = 1, Parent = row })
	slider.Changed:Connect(function(value) ... end)
]]
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Root = script.Parent.Parent
local Create = require(Root.Util.Create)
local Maid = require(Root.Util.Maid)
local Signal = require(Root.Util.Signal)
local Theme = require(Root.Core.Theme)
local Shape = require(Root.Core.Shape)
local Motion = require(Root.Core.Motion)

local Slider = {}
Slider.__index = Slider

local TRACK_HEIGHT = 16
local HANDLE_SIZE = 4
local HANDLE_HEIGHT = 44

function Slider.new(props)
	props = props or {}
	local self = setmetatable({}, Slider)
	self._maid = Maid.new()
	self._theme = props.Theme or Theme.Default()
	self._min = props.Min or 0
	self._max = props.Max or 100
	self._step = props.Step
	self._value = math.clamp(props.Value or self._min, self._min, self._max)
	self._disabled = props.Disabled or false
	self._dragging = false
	self.Changed = Signal.new()

	local root = Create("Frame") {
		Name = props.Name or "MD3Slider",
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.new(1, 0, 0, HANDLE_HEIGHT),
		LayoutOrder = props.LayoutOrder or 0,
	}

	-- Invisible full-width button so clicking/tapping anywhere on the track
	-- jumps there and starts a drag, not just on the handle.
	local trackHitArea = Create("TextButton") {
		Name = "TrackHitArea",
		AutoButtonColor = false,
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	}
	self._trackHitArea = trackHitArea

	local inactiveTrack = Create("Frame") {
		Name = "InactiveTrack",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, TRACK_HEIGHT),
		BorderSizePixel = 0,
		Parent = root,
	}
	Shape.Corner(Shape.Full, inactiveTrack)
	self._inactiveTrack = inactiveTrack

	local activeTrack = Create("Frame") {
		Name = "ActiveTrack",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(0, 0, 0, TRACK_HEIGHT),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = root,
	}
	Shape.Corner(Shape.Full, activeTrack)
	self._activeTrack = activeTrack

	local handleArea = Create("TextButton") {
		Name = "HandleArea",
		AutoButtonColor = false,
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(HANDLE_HEIGHT, HANDLE_HEIGHT),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = root,
	}
	self._handleArea = handleArea

	local handle = Create("Frame") {
		Name = "Handle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, HANDLE_SIZE, 0, TRACK_HEIGHT + 8),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = handleArea,
	}
	Shape.Corner(Shape.Full, handle)
	self._handle = handle

	self.Instance = root

	self:_render(false)
	self:_bindInput()

	self._maid:GiveTask(self._theme.Changed:Connect(function()
		self:_render(true)
	end))
	self._maid:GiveTask(root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_render(false)
	end))

	if props.Parent then
		root.Parent = props.Parent
	end

	return self
end

function Slider:_alphaFor(value: number): number
	if self._max == self._min then
		return 0
	end
	return (value - self._min) / (self._max - self._min)
end

function Slider:_render(animate: boolean)
	local c = self._theme.Colors
	local alpha = self:_alphaFor(self._value)

	local trackColor = self._disabled and c.OnSurface or c.Primary
	local inactiveColor = self._disabled and c.OnSurface or c.SecondaryContainer

	self._inactiveTrack.BackgroundColor3 = inactiveColor
	self._inactiveTrack.BackgroundTransparency = self._disabled and 0.88 or 0
	self._handle.BackgroundColor3 = trackColor
	self._handle.BackgroundTransparency = self._disabled and 0.62 or 0
	self._activeTrack.BackgroundColor3 = trackColor
	self._activeTrack.BackgroundTransparency = self._disabled and 0.88 or 0

	local targetSize = UDim2.new(alpha, 0, 0, TRACK_HEIGHT)
	local targetHandlePos = UDim2.new(alpha, 0, 0.5, 0)

	if animate then
		local ti = Motion.Standard(Motion.Duration.Short2)
		TweenService:Create(self._activeTrack, ti, { Size = targetSize }):Play()
		TweenService:Create(self._handleArea, ti, { Position = targetHandlePos }):Play()
	else
		self._activeTrack.Size = targetSize
		self._handleArea.Position = targetHandlePos
	end
end

function Slider:_valueFromInputX(inputX: number): number
	local abs = self.Instance.AbsolutePosition.X
	local width = self.Instance.AbsoluteSize.X
	if width <= 0 then
		return self._value
	end
	local alpha = math.clamp((inputX - abs) / width, 0, 1)
	local value = self._min + alpha * (self._max - self._min)
	if self._step then
		value = math.round(value / self._step) * self._step
	end
	return math.clamp(value, self._min, self._max)
end

function Slider:_bindInput()
	local handleArea = self._handleArea

	local function beginDrag(input)
		if self._disabled then
			return
		end
		self._dragging = true
		self:SetValue(self:_valueFromInputX(input.Position.X))

		local moveConn, endConn
		moveConn = UserInputService.InputChanged:Connect(function(moveInput)
			if moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch then
				if self._dragging then
					self:SetValue(self:_valueFromInputX(moveInput.Position.X))
				end
			end
		end)
		endConn = UserInputService.InputEnded:Connect(function(endInput)
			if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
				self._dragging = false
				moveConn:Disconnect()
				endConn:Disconnect()
			end
		end)
	end

	for _, target in { handleArea, self._trackHitArea } do
		self._maid:GiveTask(target.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				beginDrag(input)
			end
		end))
	end
end

function Slider:SetValue(value: number, silent: boolean?)
	value = math.clamp(value, self._min, self._max)
	if value == self._value then
		return
	end
	self._value = value
	self:_render(true)
	if not silent then
		self.Changed:Fire(value)
	end
end

function Slider:GetValue(): number
	return self._value
end

function Slider:SetDisabled(disabled: boolean)
	self._disabled = disabled
	self._handleArea.Active = not disabled
	self._trackHitArea.Active = not disabled
	self:_render(true)
end

function Slider:SetTheme(theme)
	self._theme = theme
	self:_render(true)
end

function Slider:Destroy()
	self._maid:Destroy()
	self.Changed:DisconnectAll()
	self.Instance:Destroy()
end

return Slider
