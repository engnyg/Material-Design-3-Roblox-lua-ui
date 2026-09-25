-- M3 "state layer": a full-bleed overlay tinted with the content color that
-- fades in/out to communicate hover / focus / press / drag states.
local Create = require(script.Parent.Parent.Util.Create)
local Motion = require(script.Parent.Motion)

local OPACITY = {
	Hover = 0.08,
	Focus = 0.10,
	Pressed = 0.10,
	Dragged = 0.16,
}

local StateLayer = {}
StateLayer.__index = StateLayer
StateLayer.Opacity = OPACITY

function StateLayer.new(parent: GuiObject, color: Color3, cornerRadius: UDim?)
	local self = setmetatable({}, StateLayer)

	self.Instance = Create("Frame") {
		Name = "StateLayer",
		BackgroundColor3 = color,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = parent.ZIndex + 1,
		[1] = Create("UICorner") { CornerRadius = cornerRadius or UDim.new(0, 0) },
		Parent = parent,
	}

	self._active = {}
	return self
end

function StateLayer:SetColor(color: Color3)
	self.Instance.BackgroundColor3 = color
end

-- Turns a named state (Hover/Focus/Pressed/Dragged) on or off. Multiple
-- states can be active at once; the strongest opacity wins, matching M3.
function StateLayer:SetState(name: string, active: boolean)
	self._active[name] = active or nil

	local strongest = 0
	for state in pairs(self._active) do
		strongest = math.max(strongest, OPACITY[state] or 0)
	end

	local tween = game:GetService("TweenService"):Create(
		self.Instance,
		Motion.Standard(Motion.Duration.Short2),
		{ BackgroundTransparency = 1 - strongest }
	)
	tween:Play()
end

function StateLayer:Destroy()
	self.Instance:Destroy()
end

return StateLayer
