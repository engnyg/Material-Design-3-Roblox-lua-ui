-- Material 3 shape scale (corner radius tokens).
local Shape = {
	None = UDim.new(0, 0),
	ExtraSmall = UDim.new(0, 4),
	Small = UDim.new(0, 8),
	Medium = UDim.new(0, 12),
	Large = UDim.new(0, 16),
	ExtraLarge = UDim.new(0, 28),
	Full = UDim.new(1, 0), -- pill / fully rounded, pair with UICorner on a fixed-height element
}

function Shape.Corner(radius: UDim, parent: Instance?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	if parent then
		corner.Parent = parent
	end
	return corner
end

return Shape
