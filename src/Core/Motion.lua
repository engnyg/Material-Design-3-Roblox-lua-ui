-- Material 3 motion tokens (durations) and the closest built-in Roblox easing
-- equivalents to the M3 "standard" / "emphasized" curves (Roblox TweenInfo
-- doesn't accept arbitrary cubic-bezier control points, so these are the
-- nearest EasingStyle/EasingDirection matches).
local Motion = {}

Motion.Duration = {
	Short1 = 0.05,
	Short2 = 0.10,
	Short3 = 0.15,
	Short4 = 0.20,
	Medium1 = 0.25,
	Medium2 = 0.30,
	Medium3 = 0.35,
	Medium4 = 0.40,
	Long1 = 0.45,
	Long2 = 0.50,
	Long3 = 0.55,
	Long4 = 0.60,
}

function Motion.Standard(duration: number?): TweenInfo
	return TweenInfo.new(duration or Motion.Duration.Medium2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
end

function Motion.Emphasized(duration: number?): TweenInfo
	return TweenInfo.new(duration or Motion.Duration.Medium4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
end

function Motion.Decelerate(duration: number?): TweenInfo
	return TweenInfo.new(duration or Motion.Duration.Short4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
end

function Motion.Accelerate(duration: number?): TweenInfo
	return TweenInfo.new(duration or Motion.Duration.Short2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
end

return Motion
