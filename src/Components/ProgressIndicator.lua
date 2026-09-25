--[[
	Material 3 Progress Indicators.

	MD3.ProgressIndicator.Linear({ Value = 0.4, Parent = frame })            -- determinate
	MD3.ProgressIndicator.Linear({ Indeterminate = true, Parent = frame })
	MD3.ProgressIndicator.Circular({ Value = 0.4, Parent = frame })          -- determinate
	MD3.ProgressIndicator.Circular({ Indeterminate = true, Parent = frame })
]]
local TweenService = game:GetService("TweenService")

local Root = script.Parent.Parent
local Create = require(Root.Util.Create)
local Maid = require(Root.Util.Maid)
local Theme = require(Root.Core.Theme)
local Shape = require(Root.Core.Shape)

local ProgressIndicator = {}

--============================== Linear ==============================--

local Linear = {}
Linear.__index = Linear

function ProgressIndicator.Linear(props)
	props = props or {}
	local self = setmetatable({}, Linear)
	self._maid = Maid.new()
	self._theme = props.Theme or Theme.Default()
	self._value = math.clamp(props.Value or 0, 0, 1)
	self._indeterminate = props.Indeterminate or false

	local track = Create("Frame") {
		Name = props.Name or "MD3LinearProgress",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = props.Size or UDim2.new(1, 0, 0, 4),
		LayoutOrder = props.LayoutOrder or 0,
	}
	Shape.Corner(Shape.Full, track)

	local bar = Create("Frame") {
		Name = "Bar",
		BorderSizePixel = 0,
		Size = UDim2.new(self._indeterminate and 0.3 or self._value, 0, 1, 0),
		Parent = track,
	}
	Shape.Corner(Shape.Full, bar)

	self.Instance = track
	self._bar = bar

	self:_applyTheme()

	self._maid:GiveTask(self._theme.Changed:Connect(function()
		self:_applyTheme()
	end))

	if self._indeterminate then
		self:_startIndeterminate()
	end

	if props.Parent then
		track.Parent = props.Parent
	end

	return self
end

function Linear:_applyTheme()
	self.Instance.BackgroundColor3 = self._theme.Colors.SecondaryContainer
	self._bar.BackgroundColor3 = self._theme.Colors.Primary
end

function Linear:_startIndeterminate()
	task.spawn(function()
		while self._indeterminate and self.Instance.Parent do
			local tween = TweenService:Create(self._bar, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Position = UDim2.new(0.85, 0, 0, 0),
			})
			self._bar.Position = UDim2.new(-0.3, 0, 0, 0)
			tween:Play()
			tween.Completed:Wait()
		end
	end)
end

function Linear:SetValue(value: number)
	self._indeterminate = false
	self._value = math.clamp(value, 0, 1)
	TweenService:Create(self._bar, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
		Size = UDim2.new(self._value, 0, 1, 0),
	}):Play()
end

function Linear:SetTheme(theme)
	self._theme = theme
	self:_applyTheme()
end

function Linear:Destroy()
	self._indeterminate = false
	self._maid:Destroy()
	self.Instance:Destroy()
end

--============================== Circular ==============================--

local Circular = {}
Circular.__index = Circular

local EPS = 0.004

local function arcSequence(value: number)
	if value <= 0 then
		return NumberSequence.new(1)
	elseif value >= 1 then
		return NumberSequence.new(0)
	end
	-- Keypoint times must be strictly increasing, so keep value-EPS above 0.
	value = math.clamp(value, 2 * EPS, 1 - EPS)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(value - EPS, 0),
		NumberSequenceKeypoint.new(value, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
end

function ProgressIndicator.Circular(props)
	props = props or {}
	local self = setmetatable({}, Circular)
	self._maid = Maid.new()
	self._theme = props.Theme or Theme.Default()
	self._value = math.clamp(props.Value or 0.25, 0, 1)
	self._indeterminate = props.Indeterminate or false
	local diameter = props.Diameter or 40

	local root = Create("Frame") {
		Name = props.Name or "MD3CircularProgress",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(diameter, diameter),
		LayoutOrder = props.LayoutOrder or 0,
	}

	local track = Create("Frame") {
		Name = "Track",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	}
	Shape.Corner(Shape.Full, track)
	local trackStroke = Create("UIStroke") {
		Thickness = props.Thickness or 4,
		Parent = track,
	}
	self._trackStroke = trackStroke

	local active = Create("Frame") {
		Name = "Active",
		BackgroundTransparency = 1,
		Rotation = -90,
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	}
	Shape.Corner(Shape.Full, active)
	local activeStroke = Create("UIStroke") {
		Thickness = props.Thickness or 4,
		Parent = active,
	}
	local gradient = Create("UIGradient") {
		Transparency = arcSequence(self._value),
		Parent = activeStroke,
	}
	self._activeFrame = active
	self._activeStroke = activeStroke
	self._gradient = gradient

	self.Instance = root

	self:_applyTheme()
	self._maid:GiveTask(self._theme.Changed:Connect(function()
		self:_applyTheme()
	end))

	if self._indeterminate then
		self:_startIndeterminate()
	end

	if props.Parent then
		root.Parent = props.Parent
	end

	return self
end

function Circular:_applyTheme()
	self._trackStroke.Color = self._theme.Colors.SecondaryContainer
	self._activeStroke.Color = self._theme.Colors.Primary
end

function Circular:_startIndeterminate()
	if not self._indeterminate then
		self._gradient.Transparency = arcSequence(0.28)
	end
	task.spawn(function()
		while self._indeterminate and self.Instance.Parent do
			local tween = TweenService:Create(self._activeFrame, TweenInfo.new(1.1, Enum.EasingStyle.Linear), {
				Rotation = self._activeFrame.Rotation + 360,
			})
			tween:Play()
			tween.Completed:Wait()
		end
	end)
end

function Circular:SetValue(value: number)
	self._indeterminate = false
	self._value = math.clamp(value, 0, 1)
	self._gradient.Transparency = arcSequence(self._value)
end

function Circular:SetTheme(theme)
	self._theme = theme
	self:_applyTheme()
end

function Circular:Destroy()
	self._indeterminate = false
	self._maid:Destroy()
	self.Instance:Destroy()
end

return ProgressIndicator
