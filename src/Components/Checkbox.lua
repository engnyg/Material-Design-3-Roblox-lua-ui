--[[
	Material 3 Checkbox (supports true/false/"Indeterminate").

	local cb = MD3.Checkbox.new({ Value = false, Parent = row })
	cb.Changed:Connect(function(value) ... end)
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
local Icons = require(Root.Core.Icons)

local Checkbox = {}
Checkbox.__index = Checkbox

local BOX_SIZE = 18
local HITBOX_SIZE = 40

function Checkbox.new(props)
	props = props or {}
	local self = setmetatable({}, Checkbox)
	self._maid = Maid.new()
	self._theme = props.Theme or Theme.Default()
	self._value = props.Value or false -- true | false | "Indeterminate"
	self._disabled = props.Disabled or false
	self.Changed = Signal.new()

	local hitbox = Create("TextButton") {
		Name = props.Name or "MD3Checkbox",
		AutoButtonColor = false,
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(HITBOX_SIZE, HITBOX_SIZE),
		LayoutOrder = props.LayoutOrder or 0,
	}
	Shape.Corner(Shape.Full, hitbox)

	local box = Create("Frame") {
		Name = "Box",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(BOX_SIZE, BOX_SIZE),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = hitbox,
	}
	Shape.Corner(Shape.ExtraSmall, box)

	local stroke = Create("UIStroke") {
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = box,
	}
	self._stroke = stroke

	-- Drawn as a Material icon glyph (check / remove) rather than an image
	-- asset. Renders the real Material Design flat icon once you've called
	-- MD3.Icons.SetFont(...); falls back to a plain glyph until then — see
	-- Core/Icons.lua for setup.
	local mark = Create("TextLabel") {
		Name = "Mark",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.85, 0.85),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		Parent = box,
	}
	self._mark = mark

	self.Instance = hitbox
	self._box = box
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

function Checkbox:_render(animate: boolean)
	local c = self._theme.Colors
	local checked = self._value == true or self._value == "Indeterminate"

	local boxColor = checked and (self._disabled and c.OnSurface or c.Primary) or c.Surface
	local boxTransparency = checked and (self._disabled and 0.62 or 0) or 1
	local borderColor = self._disabled and c.OnSurface or c.OnSurfaceVariant
	local borderTransparency = self._disabled and 0.62 or 0
	local markColor = self._disabled and c.Surface or c.OnPrimary

	local ti = Motion.Standard(Motion.Duration.Short2)
	local apply = animate and function(inst, props_) TweenService:Create(inst, ti, props_):Play() end
		or function(inst, props_) for k, v in pairs(props_) do inst[k] = v end end

	apply(self._box, { BackgroundColor3 = boxColor, BackgroundTransparency = boxTransparency })
	apply(self._mark, { TextColor3 = markColor, TextTransparency = checked and 0 or 1 })

	Icons.Apply(self._mark, self._value == "Indeterminate" and "remove" or "check")

	self._stroke.Color = borderColor
	self._stroke.Transparency = checked and 1 or borderTransparency
	self._stateLayer:SetColor(checked and c.Primary or c.OnSurface)
end

function Checkbox:_bindInput()
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
			self:SetValue(not (self._value == true))
		end
	end))
end

function Checkbox:SetValue(value, silent: boolean?)
	self._value = value
	self:_render(true)
	if not silent then
		self.Changed:Fire(value)
	end
end

function Checkbox:GetValue()
	return self._value
end

function Checkbox:SetDisabled(disabled: boolean)
	self._disabled = disabled
	self.Instance.Active = not disabled
	self:_render(true)
end

function Checkbox:SetTheme(theme)
	self._theme = theme
	self:_render(true)
end

function Checkbox:Destroy()
	self._stateLayer:Destroy()
	self._maid:Destroy()
	self.Changed:DisconnectAll()
	self.Instance:Destroy()
end

return Checkbox
