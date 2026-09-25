-- Drop shadows for elevated surfaces (Cards, FABs, Dialogs, Menus...).
-- Roblox has no native box-shadow, so this fakes a soft shadow with a few
-- stacked, progressively larger/more-transparent rounded frames placed as a
-- SIBLING just behind the surface (a child would always render on top,
-- since ZIndex only orders siblings, not parent vs. descendant).
-- No external image assets required.
local Create = require(script.Parent.Parent.Util.Create)

local Elevation = {}

-- level -> { yOffset (px), spread (px), baseAlpha }
local LEVELS = {
	[0] = nil,
	{ y = 1, spread = 2, alpha = 0.85 },
	{ y = 2, spread = 4, alpha = 0.80 },
	{ y = 3, spread = 6, alpha = 0.75 },
	{ y = 4, spread = 8, alpha = 0.72 },
	{ y = 5, spread = 10, alpha = 0.68 },
}

local LAYERS = 3

-- surface -> its shadow holder. Weak keys so a forgotten surface doesn't pin
-- its shadow in memory. (Instance:GetDebugId would need plugin security,
-- which normal LocalScripts and some executors don't have.)
local shadows = setmetatable({}, { __mode = "k" })

local function syncTransform(holder: Frame, surface: GuiObject)
	holder.AnchorPoint = surface.AnchorPoint
	holder.Position = surface.Position
	holder.Size = surface.Size
	holder.Rotation = surface.Rotation
	holder.LayoutOrder = surface.LayoutOrder - 1
	holder.Visible = surface.Visible
end

-- Attaches (or replaces) a shadow behind `surface`. `cornerRadius` should
-- match the surface's own UICorner so the shadow silhouette lines up.
function Elevation.Apply(surface: GuiObject, level: number, shadowColor: Color3?, cornerRadius: UDim?)
	Elevation.Remove(surface)

	local spec = LEVELS[math.clamp(level, 0, 5)]
	if not spec or not surface.Parent then
		return nil
	end

	local color = shadowColor or Color3.new(0, 0, 0)
	local radius = cornerRadius or UDim.new(0, 12)

	local holder = Create("Frame") {
		Name = "_MD3Shadow",
		BackgroundTransparency = 1,
		ZIndex = math.max(surface.ZIndex - 1, 0),
	}
	syncTransform(holder, surface)

	for i = 1, LAYERS do
		local growth = (spec.spread / LAYERS) * i
		local transparency = 1 - (spec.alpha * (1 - (i - 1) / LAYERS) * 0.33)
		Create("Frame") {
			Name = "Layer" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, spec.y),
			Size = UDim2.new(1, growth * 2, 1, growth * 2),
			BackgroundColor3 = color,
			BackgroundTransparency = math.clamp(transparency, 0, 1),
			BorderSizePixel = 0,
			ZIndex = holder.ZIndex,
			[1] = Create("UICorner") { CornerRadius = UDim.new(radius.Scale, radius.Offset + growth) },
			Parent = holder,
		}
	end

	holder.Parent = surface.Parent
	shadows[surface] = holder

	local connections = {}
	table.insert(connections, surface:GetPropertyChangedSignal("Position"):Connect(function()
		syncTransform(holder, surface)
	end))
	table.insert(connections, surface:GetPropertyChangedSignal("Size"):Connect(function()
		syncTransform(holder, surface)
	end))
	table.insert(connections, surface:GetPropertyChangedSignal("AnchorPoint"):Connect(function()
		syncTransform(holder, surface)
	end))
	table.insert(connections, surface:GetPropertyChangedSignal("Visible"):Connect(function()
		syncTransform(holder, surface)
	end))
	table.insert(connections, surface.AncestryChanged:Connect(function(_, parent)
		if not parent then
			holder:Destroy()
		end
	end))
	table.insert(connections, surface.Destroying:Connect(function()
		holder:Destroy()
	end))
	table.insert(connections, holder.Destroying:Connect(function()
		if shadows[surface] == holder then
			shadows[surface] = nil
		end
		for _, c in connections do
			c:Disconnect()
		end
	end))

	return holder
end

function Elevation.Remove(surface: GuiObject)
	local holder = shadows[surface]
	if holder then
		shadows[surface] = nil
		holder:Destroy()
	end
end

return Elevation
