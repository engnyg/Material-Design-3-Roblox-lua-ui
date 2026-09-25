-- M3 ripple: an expanding, fading circle spawned at the input position on
-- press. Purely decorative feedback layered on top of the StateLayer.
local TweenService = game:GetService("TweenService")
local Create = require(script.Parent.Parent.Util.Create)

local Ripple = {}

-- `inputPosition` is usually InputObject.Position, which is a Vector3 in
-- Roblox; only its X / Y matter (Vector3 - Vector2 would throw).
function Ripple.Emit(parent: GuiObject, inputPosition: Vector2 | Vector3, color: Color3)
	local absPos, absSize = parent.AbsolutePosition, parent.AbsoluteSize
	if absSize.X <= 0 or absSize.Y <= 0 then
		return
	end

	local localPos = Vector2.new(inputPosition.X, inputPosition.Y) - absPos
	-- Diameter big enough to cover the furthest corner from the tap point.
	local maxDist = math.max(
		(localPos - Vector2.new(0, 0)).Magnitude,
		(localPos - Vector2.new(absSize.X, 0)).Magnitude,
		(localPos - Vector2.new(0, absSize.Y)).Magnitude,
		(localPos - Vector2.new(absSize.X, absSize.Y)).Magnitude
	)
	local diameter = maxDist * 2

	local circle = Create("Frame") {
		Name = "Ripple",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(localPos.X, localPos.Y),
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		ZIndex = parent.ZIndex + 2,
		[1] = Create("UICorner") { CornerRadius = UDim.new(1, 0) },
		Parent = parent,
	}

	local grow = TweenService:Create(circle, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(diameter, diameter),
	})
	local fade = TweenService:Create(circle, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	})

	grow:Play()
	task.delay(0.15, function()
		fade:Play()
	end)
	fade.Completed:Once(function()
		circle:Destroy()
	end)
end

return Ripple
