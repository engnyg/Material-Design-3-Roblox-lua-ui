-- Binds plain Instance properties to theme color roles so hand-built window
-- chrome recolors on Theme.Changed the same way the components do.
--
--   themer:Bind(frame, { BackgroundColor3 = "SurfaceContainerHigh" })
--   themer:Bind(label, { TextColor3 = function(c) return c.Primary end })
--   themer:Bind(label, { TextColor3 = Color3.fromRGB(255, 0, 0) }) -- fixed color
local Themer = {}
Themer.__index = Themer

-- Color property -> the transparency property that goes with it. A role's
-- theme transparency (Theme:SetTransparency / the theme editor's opacity
-- bar) is applied there too.
local TRANSPARENCY_PROP = {
	BackgroundColor3 = "BackgroundTransparency",
	TextColor3 = "TextTransparency",
	ImageColor3 = "ImageTransparency",
	Color = "Transparency", -- UIStroke
	ScrollBarImageColor3 = "ScrollBarImageTransparency",
}

-- `touched[prop]` remembers transparency this Themer set, so it can be
-- put back to opaque when the role's transparency is removed (and is left
-- alone otherwise, e.g. a label that's transparent on purpose).
local function apply(inst, map, theme, touched)
	local colors = theme.Colors
	for prop, role in map do
		if type(role) == "function" then
			inst[prop] = role(colors)
		elseif typeof(role) == "Color3" then
			inst[prop] = role
		else
			inst[prop] = colors[role]
			local transparencyProp = TRANSPARENCY_PROP[prop]
			if transparencyProp then
				local value = theme:GetTransparency(role)
				if value then
					inst[transparencyProp] = value
					touched[transparencyProp] = true
				elseif touched[transparencyProp] then
					inst[transparencyProp] = 0
					touched[transparencyProp] = nil
				end
			end
		end
	end
end

function Themer.new(theme)
	local self = setmetatable({}, Themer)
	self.Theme = theme
	-- Strong keys on purpose: Roblox may collect and recreate an Instance's
	-- Lua wrapper, which would silently drop weak-keyed bindings. Entries
	-- are removed when the instance is destroyed instead.
	self._bindings = {}
	self._touched = {}
	self._cleanup = {}
	self._connection = theme.Changed:Connect(function()
		self:Refresh()
	end)
	return self
end

function Themer:Bind(inst: Instance, map)
	local existing = self._bindings[inst]
	if existing then
		for prop, role in map do
			existing[prop] = role
		end
	else
		self._bindings[inst] = map
		self._touched[inst] = {}
		self._cleanup[inst] = inst.Destroying:Connect(function()
			self:Unbind(inst)
		end)
	end
	apply(inst, map, self.Theme, self._touched[inst])
	return inst
end

function Themer:Unbind(inst: Instance)
	self._bindings[inst] = nil
	self._touched[inst] = nil
	local connection = self._cleanup[inst]
	if connection then
		self._cleanup[inst] = nil
		connection:Disconnect()
	end
end

function Themer:Refresh()
	for inst, map in self._bindings do
		if inst.Parent then
			apply(inst, map, self.Theme, self._touched[inst])
		end
	end
end

function Themer:Destroy()
	self._connection:Disconnect()
	for _, connection in self._cleanup do
		connection:Disconnect()
	end
	table.clear(self._cleanup)
	table.clear(self._bindings)
	table.clear(self._touched)
end

return Themer
