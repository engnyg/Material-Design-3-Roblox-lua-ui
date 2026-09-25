-- Minimal stand-ins for the Roblox globals the library touches, so the
-- bundle can be loaded and exercised under the standalone `luau` CLI.
-- Fidelity is intentionally shallow: enough to catch load errors, bad
-- requires, nil indexing and invalid NumberSequences, not rendering bugs.

local function makeSignal()
	local handlers = {}
	local signal = {}
	function signal:Connect(fn)
		local conn = { Connected = true }
		handlers[conn] = fn
		function conn:Disconnect()
			handlers[conn] = nil
			conn.Connected = false
		end
		return conn
	end
	function signal:Once(fn)
		local conn
		conn = signal:Connect(function(...)
			conn:Disconnect()
			fn(...)
		end)
		return conn
	end
	function signal:Wait()
		return coroutine.yield()
	end
	function signal:Fire(...)
		for conn, fn in handlers do
			if conn.Connected then
				fn(...)
			end
		end
	end
	return signal
end

-- Roblox value types are userdata; the mock builds them with newproxy and
-- records the Roblox type name in a __type metafield, which the typeof
-- override at the bottom reports. (test.luau setfenv's the bundle chunk so
-- that override is used instead of Luau's builtin fast path.)
local function hostValue(typeName, index, extra)
	local proxy = newproxy(true)
	local mt = getmetatable(proxy)
	mt.__type = typeName
	mt.__index = index
	for k, v in extra or {} do
		mt[k] = v
	end
	return proxy
end

local enumCache = {}
local function enumProxy(path)
	if enumCache[path] then
		return enumCache[path]
	end
	local depth = select(2, path:gsub("%.", "")) -- 0 = Enum, 1 = Enum.X, 2 = Enum.X.Y
	local lastSegment = path:match("([^%.]+)$")
	local proxy = hostValue(depth == 2 and "EnumItem" or depth == 1 and "Enum" or "Enums", function(_, key)
		if depth == 2 and key == "Name" then
			return lastSegment
		elseif depth == 2 and key == "EnumType" then
			return enumProxy(path:match("^(.*)%.[^%.]+$"))
		end
		return enumProxy(path .. "." .. key)
	end, {
		-- Like Roblox: tostring(Enum.KeyCode) == "KeyCode",
		-- tostring(Enum.KeyCode.Q) == "Enum.KeyCode.Q"
		__tostring = function()
			return depth == 1 and lastSegment or path
		end,
	})
	enumCache[path] = proxy
	return proxy
end
Enum = enumProxy("Enum")

Color3 = {}
local Color3Methods = {}
local function color3Eq(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
local function color3ToString(c)
	return `Color3({c.R}, {c.G}, {c.B})`
end
function Color3.new(r, g, b)
	local data = { R = r or 0, G = g or 0, B = b or 0 }
	return hostValue("Color3", function(_, key)
		local v = data[key]
		if v ~= nil then
			return v
		end
		return Color3Methods[key]
	end, { __eq = color3Eq, __tostring = color3ToString })
end
function Color3.fromRGB(r, g, b)
	return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
function Color3.fromHex(hex)
	hex = hex:gsub("#", "")
	assert(#hex == 6, "Unable to convert characters to hex value")
	return Color3.new(
		tonumber(hex:sub(1, 2), 16) / 255,
		tonumber(hex:sub(3, 4), 16) / 255,
		tonumber(hex:sub(5, 6), 16) / 255
	)
end
function Color3.fromHSV(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then return Color3.new(v, t, p) end
	if i == 1 then return Color3.new(q, v, p) end
	if i == 2 then return Color3.new(p, v, t) end
	if i == 3 then return Color3.new(p, q, v) end
	if i == 4 then return Color3.new(t, p, v) end
	return Color3.new(v, p, q)
end
function Color3Methods:ToHSV()
	local r, g, b = self.R, self.G, self.B
	local max, min = math.max(r, g, b), math.min(r, g, b)
	local d = max - min
	local h = 0
	if d > 0 then
		if max == r then
			h = ((g - b) / d) % 6
		elseif max == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h /= 6
	end
	return h, max == 0 and 0 or d / max, max
end
function Color3Methods:ToHex()
	return string.format("%02x%02x%02x", math.round(self.R * 255), math.round(self.G * 255), math.round(self.B * 255))
end

ColorSequenceKeypoint = { new = function(t, c) return { Time = t, Value = c } end }
ColorSequence = {
	new = function(arg)
		if type(arg) ~= "table" or arg[1] == nil then
			return { Keypoints = { { Time = 0, Value = arg }, { Time = 1, Value = arg } } }
		end
		assert(arg[1].Time == 0 and arg[#arg].Time == 1, "ColorSequence must span 0..1")
		return { Keypoints = arg }
	end,
}

Font = { fromEnum = function(e) return { Family = tostring(e) } end, new = function(f) return { Family = f } end }

UDim = { new = function(s, o) return { Scale = s or 0, Offset = o or 0 } end }
local function udim2Eq(a, b)
	return a.X.Scale == b.X.Scale and a.X.Offset == b.X.Offset and a.Y.Scale == b.Y.Scale and a.Y.Offset == b.Y.Offset
end
UDim2 = {
	new = function(xs, xo, ys, yo)
		local data = { X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }
		return hostValue("UDim2", function(_, key)
			return data[key]
		end, { __eq = udim2Eq })
	end,
	fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end,
	fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end,
}

local Vector2Meta = {}
Vector2 = {}
function Vector2.new(x, y)
	x, y = x or 0, y or 0
	return setmetatable({ X = x, Y = y, Magnitude = math.sqrt(x * x + y * y) }, Vector2Meta)
end
Vector2Meta.__sub = function(a, b) return Vector2.new(a.X - b.X, a.Y - b.Y) end
Vector2Meta.__add = function(a, b) return Vector2.new(a.X + b.X, a.Y + b.Y) end
Vector2Meta.__div = function(a, b) return Vector2.new(a.X / b, a.Y / b) end
Vector2Meta.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end

TweenInfo = { new = function(...) return { ... } end }

warn = function(...)
	print("WARN", ...)
end

NumberSequenceKeypoint = { new = function(t, v) return { Time = t, Value = v } end }
NumberSequence = {
	new = function(arg)
		if type(arg) == "number" then
			return { Keypoints = { { Time = 0, Value = arg }, { Time = 1, Value = arg } } }
		end
		assert(#arg >= 2, "NumberSequence needs at least 2 keypoints")
		assert(arg[1].Time == 0, "NumberSequence must start at time 0")
		assert(arg[#arg].Time == 1, "NumberSequence must end at time 1")
		for i = 2, #arg do
			assert(arg[i].Time > arg[i - 1].Time, `NumberSequence keypoint times must increase (got {arg[i - 1].Time} then {arg[i].Time})`)
		end
		return { Keypoints = arg }
	end,
}

local EVENTS = {
	MouseEnter = true, MouseLeave = true, InputBegan = true, InputEnded = true, InputChanged = true,
	Activated = true, MouseButton1Click = true, Focused = true, FocusLost = true,
	Destroying = true, AncestryChanged = true, Changed = true,
}

local debugCounter = 0
local InstanceMeta = {}
InstanceMeta.__index = function(self, key)
	local props = rawget(self, "_props")
	if props[key] ~= nil then
		return props[key]
	end
	if EVENTS[key] then
		local signal = makeSignal()
		props[key] = signal
		return signal
	end
	local child = rawget(self, "_children")[key]
	if child then
		return child
	end
	return InstanceMeta.methods[key]
end
InstanceMeta.__newindex = function(self, key, value)
	local props = rawget(self, "_props")
	if key == "Parent" then
		local old = props.Parent
		if old then
			local list = rawget(old, "_childList")
			table.remove(list, table.find(list, self))
			rawget(old, "_children")[props.Name] = nil
		end
		props.Parent = value
		if value then
			table.insert(rawget(value, "_childList"), self)
			rawget(value, "_children")[props.Name] = self
		end
		return
	end
	props[key] = value
	local propSignals = rawget(self, "_propSignals")
	if propSignals[key] then
		propSignals[key]:Fire()
	end
end

InstanceMeta.methods = {
	Destroy = function(self)
		if rawget(self, "_destroyed") then
			return
		end
		rawset(self, "_destroyed", true)
		self.Destroying:Fire()
		for _, child in table.clone(rawget(self, "_childList")) do
			child:Destroy()
		end
		self.Parent = nil
	end,
	GetChildren = function(self) return table.clone(rawget(self, "_childList")) end,
	FindFirstChild = function(self, name) return rawget(self, "_children")[name] end,
	WaitForChild = function(self, name) return rawget(self, "_children")[name] end,
	SetAttribute = function(self, k, v) rawget(self, "_attrs")[k] = v end,
	GetAttribute = function(self, k) return rawget(self, "_attrs")[k] end,
	GetDebugId = function(self) return rawget(self, "_debugId") end,
	GetPropertyChangedSignal = function(self, key)
		local propSignals = rawget(self, "_propSignals")
		propSignals[key] = propSignals[key] or makeSignal()
		return propSignals[key]
	end,
	IsA = function(self, className) return self.ClassName == className end,
	FindFirstChildOfClass = function(self, className)
		for _, child in rawget(self, "_childList") do
			if child.ClassName == className then
				return child
			end
		end
		return nil
	end,
	GetFocusedTextBox = function() return nil end,
}

-- Every instance created, so tests can inspect everything the library built.
MOCK_INSTANCES = {}

Instance = {}
function Instance.new(className)
	debugCounter += 1
	local inst = setmetatable({
		_props = {
			ClassName = className,
			Name = className,
			ZIndex = 1,
			LayoutOrder = 0,
			Size = UDim2.new(0, 0, 0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			AnchorPoint = Vector2.new(0, 0),
			Rotation = 0,
			Visible = true, -- GuiObjects are visible by default in Roblox
			AbsolutePosition = Vector2.new(0, 0),
			AbsoluteSize = Vector2.new(100, 40),
			Text = "",
		},
		_children = {},
		_childList = {},
		_attrs = {},
		_propSignals = {},
		_debugId = tostring(debugCounter),
	}, InstanceMeta)
	table.insert(MOCK_INSTANCES, inst)
	return inst
end

-- Tweens apply their goals instantly, but (like real Roblox) Completed only
-- fires later — call flushTweens() to simulate the tweens finishing.
local pendingTweens = {}
function flushTweens()
	local pending = pendingTweens
	pendingTweens = {}
	for _, tween in pending do
		tween.Completed:Fire(Enum.PlaybackState.Completed)
	end
end

local services = {}
services.TweenService = {
	Create = function(_, inst, _info, goals)
		local tween = { Completed = makeSignal() }
		function tween:Play()
			for k, v in goals do
				inst[k] = v
			end
			table.insert(pendingTweens, tween)
		end
		return tween
	end,
}
services.UserInputService = {
	InputBegan = makeSignal(),
	InputChanged = makeSignal(),
	InputEnded = makeSignal(),
	TouchEnabled = false,
	KeyboardEnabled = true,
	GetFocusedTextBox = function() return nil end,
}

-- JSON stand-in: keeps encoded tables in memory and hands back a key,
-- which is enough to round-trip configs through the fake file system.
local jsonStore = {}
services.HttpService = {
	JSONEncode = function(_, value)
		local key = `json#{#jsonStore + 1}`
		table.insert(jsonStore, value)
		jsonStore[key] = value
		return key
	end,
	JSONDecode = function(_, text)
		return jsonStore[text] or error("mock JSONDecode: unknown payload")
	end,
}

-- Asset loading always "succeeds" unless a test sets MOCK_ASSET_STATUS.
services.ContentProvider = {
	PreloadAsync = function(_, list, callback)
		for _, item in list do
			if callback then
				callback(item, MOCK_ASSET_STATUS or Enum.AssetFetchStatus.Success)
			end
		end
	end,
}

-- Heartbeat only fires when a test calls services.RunService.Heartbeat:Fire(dt).
services.RunService = { Heartbeat = makeSignal(), RenderStepped = makeSignal() }

local localPlayer = Instance.new("Player")
localPlayer.GetNetworkPing = function()
	return 0.045
end
local playerGui = Instance.new("PlayerGui")
playerGui.Name = "PlayerGui"
playerGui.Parent = localPlayer
services.Players = { LocalPlayer = localPlayer }

local camera = Instance.new("Camera")
camera.ViewportSize = Vector2.new(1280, 720)
workspace = { CurrentCamera = camera }

game = {
	GetService = function(_, name)
		return services[name] or error(`mock has no service {name}`)
	end,
}


task = {
	spawn = function(fn, ...)
		local co = coroutine.create(fn)
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			error(err, 0)
		end
	end,
	delay = function() end,
	wait = function() return coroutine.yield() end,
}

-- typeof that knows the mock's Roblox value types.
local nativeTypeof = typeof
typeof = function(value)
	if type(value) == "userdata" then
		local mt = getmetatable(value)
		if type(mt) == "table" and mt.__type then
			return mt.__type
		end
	elseif type(value) == "table" and getmetatable(value) == InstanceMeta then
		return "Instance"
	end
	return nativeTypeof(value)
end

return { makeSignal = makeSignal }
