-- Binds plain Instance properties to theme color roles so hand-built window
-- chrome recolors on Theme.Changed the same way the components do.
--
--   themer:Bind(frame, { BackgroundColor3 = "SurfaceContainerHigh" })
--   themer:Bind(label, { TextColor3 = function(c) return c.Primary end })
--   themer:Bind(label, { TextColor3 = Color3.fromRGB(255, 0, 0) }) -- fixed color
local Themer = {}
Themer.__index = Themer

local function apply(inst, map, colors)
	for prop, role in map do
		if type(role) == "function" then
			inst[prop] = role(colors)
		elseif typeof(role) == "Color3" then
			inst[prop] = role
		else
			inst[prop] = colors[role]
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
		self._cleanup[inst] = inst.Destroying:Connect(function()
			self:Unbind(inst)
		end)
	end
	apply(inst, map, self.Theme.Colors)
	return inst
end

function Themer:Unbind(inst: Instance)
	self._bindings[inst] = nil
	local connection = self._cleanup[inst]
	if connection then
		self._cleanup[inst] = nil
		connection:Disconnect()
	end
end

function Themer:Refresh()
	local colors = self.Theme.Colors
	for inst, map in self._bindings do
		if inst.Parent then
			apply(inst, map, colors)
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
end

return Themer
