--[[
	Material 3 Switch.

	local sw = MD3.Switch.new({ Value = false, Parent = row })
	sw.Changed:Connect(function(value) ... end)
]]
local TweenService = game:GetService("TweenService")

local Root = script.Parent.Parent
local Create = require(Root.Util.Create)
local Maid = require(Root.Util.Maid)
local Signal = require(Root.Util.Signal)
local Theme = require(Root.Core.Theme)
local Shape = require(Root.Core.Shape)
local Motion = require(Root.Core.Motion)
local Assets = require(Root.Executor.Assets)

local Switch = {}
Switch.__index = Switch

local TRACK_SIZE = UDim2.fromOffset(52, 32)
local THUMB_OFF = 16
local THUMB_ON = 24
local THUMB_PRESSED = 28

function Switch.new(props)
	props = props or {}
	local self = setmetatable({}, Switch)
	self._maid = Maid.new()
	self._theme = props.Theme or Theme.Default()
	self._value = props.Value or false
	self._disabled = props.Disabled or false
	self.Changed = Signal.new()

	local track = Create("TextButton") {
		Name = props.Name or "MD3Switch",
		AutoButtonColor = false,
		Text = "",
		Size = TRACK_SIZE,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder or 0,
	}
	Shape.Corner(Shape.Full, track)

	local stroke = Create("UIStroke") {
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = track,
	}
	self._stroke = stroke

	local thumb = Create("Frame") {
		Name = "Thumb",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromOffset(THUMB_OFF, THUMB_OFF),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = track,
	}
	Shape.Corner(Shape.Full, thumb)

	-- Optional checkmark glyph shown on the thumb when toggled on; pass your
	-- own icon asset via props.CheckedIcon, otherwise the switch stays iconless
	-- (a valid M3 switch style).
	local checkIcon = Create("ImageLabel") {
		Name = "Check",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.7),
		Image = Assets.Resolve(props.CheckedIcon),
		ImageTransparency = 1,
		Parent = thumb,
	}
	self._checkIcon = checkIcon

	self.Instance = track
	self._thumb = thumb

	self:_render(false)
	self:_bindInput()

	self._maid:GiveTask(self._theme.Changed:Connect(function()
		self:_render(true)
	end))

	if props.Parent then
		track.Parent = props.Parent
	end

	return self
end

function Switch:_render(animate: boolean)
	local c = self._theme.Colors
	local trackColor, thumbColor, borderColor, thumbSize, thumbPos

	if self._value then
		trackColor = self._disabled and c.OnSurface or c.Primary
		thumbColor = self._disabled and c.Surface or c.OnPrimary
		borderColor = trackColor
		thumbSize = THUMB_ON
		thumbPos = UDim2.new(1, -6 - thumbSize, 0.5, 0)
	else
		trackColor = self._disabled and c.SurfaceContainerHighest or c.SurfaceContainerHighest
		thumbColor = self._disabled and c.OnSurface or c.Outline
		borderColor = self._disabled and c.OnSurface or c.Outline
		thumbSize = THUMB_OFF
		thumbPos = UDim2.new(0, 6, 0.5, 0)
	end

	local containerTransparency = self._disabled and 0.88 or 0
	local thumbTransparency = self._disabled and (self._value and 0.62 or 0.38) or 0

	if animate then
		local ti = Motion.Standard(Motion.Duration.Short3)
		TweenService:Create(self.Instance, ti, { BackgroundColor3 = trackColor, BackgroundTransparency = containerTransparency }):Play()
		TweenService:Create(self._thumb, ti, {
			BackgroundColor3 = thumbColor,
			BackgroundTransparency = thumbTransparency,
			Size = UDim2.fromOffset(thumbSize, thumbSize),
			Position = thumbPos,
		}):Play()
	else
		self.Instance.BackgroundColor3 = trackColor
		self.Instance.BackgroundTransparency = containerTransparency
		self._thumb.BackgroundColor3 = thumbColor
		self._thumb.BackgroundTransparency = thumbTransparency
		self._thumb.Size = UDim2.fromOffset(thumbSize, thumbSize)
		self._thumb.Position = thumbPos
	end

	self._stroke.Color = borderColor
	self._stroke.Transparency = self._value and 1 or (self._disabled and 0.88 or 0)
	self._checkIcon.ImageColor3 = c.OnPrimaryContainer
	self._checkIcon.ImageTransparency = self._value and 0 or 1
end

function Switch:_bindInput()
	local track = self.Instance
	self._maid:GiveTask(track.MouseEnter:Connect(function()
		if not self._disabled then
			TweenService:Create(self._thumb, Motion.Standard(Motion.Duration.Short2), {
				Size = UDim2.fromOffset(THUMB_PRESSED, THUMB_PRESSED),
			}):Play()
		end
	end))
	self._maid:GiveTask(track.MouseLeave:Connect(function()
		if not self._disabled then
			local size = self._value and THUMB_ON or THUMB_OFF
			TweenService:Create(self._thumb, Motion.Standard(Motion.Duration.Short2), {
				Size = UDim2.fromOffset(size, size),
			}):Play()
		end
	end))
	self._maid:GiveTask(track.Activated:Connect(function()
		if not self._disabled then
			self:SetValue(not self._value)
		end
	end))
end

function Switch:SetValue(value: boolean, silent: boolean?)
	if self._value == value then
		return
	end
	self._value = value
	self:_render(true)
	if not silent then
		self.Changed:Fire(value)
	end
end

function Switch:GetValue(): boolean
	return self._value
end

function Switch:SetDisabled(disabled: boolean)
	self._disabled = disabled
	self.Instance.Active = not disabled
	self:_render(true)
end

function Switch:SetTheme(theme)
	self._theme = theme
	self:_render(true)
end

function Switch:Destroy()
	self._maid:Destroy()
	self.Changed:DisconnectAll()
	self.Instance:Destroy()
end

return Switch
