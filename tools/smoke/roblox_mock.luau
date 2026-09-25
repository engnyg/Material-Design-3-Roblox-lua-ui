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

local enumCache = {}
local function enumProxy(path)
	if enumCache[path] then
		return enumCache[path]
	end
	local proxy = setmetatable({}, {
		__index = function(_, key)
			return enumProxy(path .. "." .. key)
		end,
		__tostring = function()
			return path
		end,
	})
	enumCache[path] = proxy
	return proxy
end
Enum = enumProxy("Enum")

Color3 = {}
local Color3Meta = { __tostring = function(c) return `Color3({c.R}, {c.G}, {c.B})` end }
function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3Meta)
end
function Color3.fromHex(hex)
	hex = hex:gsub("#", "")
	return Color3.new(
		tonumber(hex:sub(1, 2), 16) / 255,
		tonumber(hex:sub(3, 4), 16) / 255,
		tonumber(hex:sub(5, 6), 16) / 255
	)
end

Font = { fromEnum = function(e) return { Family = tostring(e) } end, new = function(f) return { Family = f } end }

UDim = { new = function(s, o) return { Scale = s or 0, Offset = o or 0 } end }
UDim2 = {
	new = function(xs, xo, ys, yo)
		return { X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }
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

TweenInfo = { new = function(...) return { ... } end }

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
}

Instance = {}
function Instance.new(className)
	debugCounter += 1
	return setmetatable({
		_props = {
			ClassName = className,
			Name = className,
			ZIndex = 1,
			LayoutOrder = 0,
			Size = UDim2.new(0, 0, 0, 0),
			Position = UDim2.new(0, 0, 0, 0),
			AnchorPoint = Vector2.new(0, 0),
			Rotation = 0,
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
services.UserInputService = { InputChanged = makeSignal(), InputEnded = makeSignal() }
services.Players = { LocalPlayer = { PlayerGui = Instance.new("PlayerGui") } }

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

return { makeSignal = makeSignal }
