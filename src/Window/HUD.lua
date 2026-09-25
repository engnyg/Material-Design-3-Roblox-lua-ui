--[[
	On-screen HUD for executor windows: stays visible while the window is
	hidden, follows the window's theme, and every piece can be dragged.

	local wm = Window:AddWatermark({ Title = "My Hub", FPS = true, Ping = true, Clock = true })
	local block = wm:AddBlock("bolt", "Ready")   -- or wm:AddBlock({ Icon, Text, Callback })
	block:SetText("Running")

	local binds = Window:AddKeybindList()         -- lists keybinds that are switched on / held

	local auto = Window:AddIndicator({ Text = "AUTO", Icon = "bolt", Color = "Primary" })
	auto:SetColor("Error")

	Window:SetHUDVisible(false)                    -- hide every HUD piece at once
]]
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Root = script.Parent.Parent
local Create = require(Root.Util.Create)
local Maid = require(Root.Util.Maid)
local Typography = require(Root.Core.Typography)
local Shape = require(Root.Core.Shape)
local Base = require(script.Parent.Elements.Base)
local makeDraggable = require(script.Parent.Draggable)

local HUD = {}

local MARGIN = 16

-- Position presets: { Position, AnchorPoint }
local PRESETS = {
	TopLeft = { UDim2.new(0, MARGIN, 0, MARGIN), Vector2.new(0, 0) },
	Top = { UDim2.new(0.5, 0, 0, MARGIN), Vector2.new(0.5, 0) },
	TopRight = { UDim2.new(1, -MARGIN, 0, MARGIN), Vector2.new(1, 0) },
	Left = { UDim2.new(0, MARGIN, 0.5, 0), Vector2.new(0, 0.5) },
	Right = { UDim2.new(1, -MARGIN, 0.5, 0), Vector2.new(1, 0.5) },
	BottomLeft = { UDim2.new(0, MARGIN, 1, -MARGIN), Vector2.new(0, 1) },
	Bottom = { UDim2.new(0.5, 0, 1, -MARGIN), Vector2.new(0.5, 1) },
	BottomRight = { UDim2.new(1, -MARGIN, 1, -MARGIN), Vector2.new(1, 1) },
}

-- `position`: a preset name or a UDim2 (top-left corner).
local function place(frame: GuiObject, position, default: string)
	if typeof(position) == "UDim2" then
		frame.AnchorPoint = Vector2.new(0, 0)
		frame.Position = position
		return
	end
	local preset = PRESETS[position] or PRESETS[default]
	frame.Position = preset[1]
	frame.AnchorPoint = preset[2]
end

-- The rounded, outlined surface every HUD piece is drawn on.
local function surface(themer, className: string, props)
	local frame = Create(className)(props)
	themer:Bind(frame, { BackgroundColor3 = "SurfaceContainerHigh" })
	themer:Bind(Create("UIStroke") {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 1,
		Parent = frame,
	}, { Color = "OutlineVariant" })
	return frame
end

-- Re-colors an icon made by Base.Glyph with a theme role or a Color3.
local function bindIconColor(themer, icon: GuiObject, color)
	if icon:IsA("ImageLabel") then
		themer:Bind(icon, { ImageColor3 = color })
	else
		themer:Bind(icon, { TextColor3 = color })
	end
end

-- `tint` = false keeps a colored image (e.g. a logo) as-is.
local function makeIcon(themer, name, size: number, color, parent: Instance, order: number, tint: boolean?)
	if not name or not Base.CanShowIcon(name) then
		return nil
	end
	local icon = Base.Glyph(themer, name, size, color, parent, tint)
	icon.LayoutOrder = order
	return icon
end

-- One full-screen frame per window holding every HUD piece. It lives beside
-- the window's Main frame (not inside it), so hiding or minimizing the
-- window leaves the HUD up. Shrinks on small screens like the window does.
function HUD.Layer(window)
	if window._hudLayer then
		return window._hudLayer
	end
	local layer = Create("Frame") {
		Name = "HUD",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0, -- under the window; the HUD shouldn't cover the menu
		Parent = window.Gui,
	}
	local scale = Create("UIScale") { Parent = layer }
	local function rescale()
		local camera = workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
		local s = math.clamp(math.min(viewport.X / 1000, viewport.Y / 600), 0.6, 1)
		scale.Scale = s
		-- UIScale shrinks the layer itself too; grow it back to cover the screen.
		layer.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	rescale()
	local camera = workspace.CurrentCamera
	if camera then
		window._maid:GiveTask(camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale))
	end
	window._hudLayer = layer
	return layer
end

--== Watermark ==--

local Block = {}
Block.__index = Block

local Watermark = {}
Watermark.__index = Watermark

function HUD.Watermark(window, props)
	props = props or {}
	local themer = window._themer
	local self = setmetatable({
		_window = window,
		_blocks = {},
		_order = 0,
		_fast = {}, -- updaters run every 0.5 s (FPS)
		_slow = {}, -- updaters run every second (ping, clock)
		_maid = Maid.new(),
	}, Watermark)

	local frame = surface(themer, "Frame", {
		Name = "Watermark",
		BorderSizePixel = 0,
		Active = true,
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = props.Visible ~= false,
		[1] = Create("UIPadding") { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) },
		[2] = Create("UIListLayout") {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		},
	})
	Shape.Corner(Shape.Full, frame)
	place(frame, props.Position, "TopLeft")
	frame.Parent = HUD.Layer(window)
	self.Instance = frame
	makeDraggable(self._maid, frame, frame)
	window._maid:GiveTask(self)

	local title = props.Title
	if title == nil then
		title = window.Title
	end
	if title ~= false then
		-- Defaults to the window's own icon / logo (a logo keeps its colors).
		local icon, tint = props.Icon, true
		if icon == nil then
			icon, tint = window._appIconSource, window._appIconTint
		end
		self.TitleBlock = self:AddBlock({
			Icon = icon or nil,
			Text = title,
			IconColor = props.IconColor or "IconAccent",
			Tint = tint,
			Emphasis = true,
		})
	end
	if props.FPS then
		self:AddFPS()
	end
	if props.Ping then
		self:AddPing()
	end
	if props.Clock then
		self:AddClock(type(props.Clock) == "string" and props.Clock or nil)
	end
	return self
end

-- AddBlock(icon, text) or AddBlock({ Icon, Text, IconColor, TextColor, Callback, Tint }).
-- Returns a block with :SetText / :SetIcon / :SetVisible / :OnClick / :Destroy.
function Watermark:AddBlock(iconOrProps, text: string?)
	local props = if type(iconOrProps) == "table" then iconOrProps else { Icon = iconOrProps, Text = text }
	local themer = self._window._themer
	self._order += 1

	local separator = Create("Frame") {
		Name = "Separator",
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(1, 16),
		LayoutOrder = self._order * 2 - 1,
		Parent = self.Instance,
	}
	themer:Bind(separator, { BackgroundColor3 = "OutlineVariant" })

	local frame = Create("Frame") {
		Name = "Block",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = self._order * 2,
		[1] = Create("UIListLayout") {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		},
		Parent = self.Instance,
	}

	local label = Create("TextLabel") {
		Name = "Text",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = tostring(props.Text or ""),
		LayoutOrder = 2,
		Parent = frame,
	}
	Typography.Apply(label, if props.Emphasis then "TitleSmall" else "LabelLarge")
	themer:Bind(label, { TextColor3 = props.TextColor or "OnSurface" })

	local block = setmetatable({
		Instance = frame,
		_watermark = self,
		_separator = separator,
		_label = label,
		_iconColor = props.IconColor or "Icon",
		_callbacks = {},
		_visible = true,
		_maid = Maid.new(),
	}, Block)
	block._icon = makeIcon(themer, props.Icon, 16, block._iconColor, frame, 1, props.Tint)
	if props.Callback then
		table.insert(block._callbacks, props.Callback)
	end

	-- Dragging a block drags the whole watermark; a click without moving
	-- runs the block's callbacks.
	makeDraggable(block._maid, frame, self.Instance, function()
		for _, fn in block._callbacks do
			self._window:_call(fn)
		end
	end)

	table.insert(self._blocks, block)
	self:_refreshSeparators()
	return block
end

-- Only separators between two visible blocks are shown.
function Watermark:_refreshSeparators()
	local first = true
	for _, block in self._blocks do
		block._separator.Visible = block._visible and not first
		if block._visible then
			first = false
		end
	end
end

function Watermark:_startTicker()
	if self._ticking then
		return
	end
	self._ticking = true
	local frames, elapsed, slowElapsed = 0, 0, 0
	self._maid:GiveTask(RunService.Heartbeat:Connect(function(dt)
		frames += 1
		elapsed += dt
		slowElapsed += dt
		if elapsed >= 0.5 then
			self.FPS = math.round(frames / elapsed)
			frames, elapsed = 0, 0
			for _, update in self._fast do
				update()
			end
		end
		if slowElapsed >= 1 then
			slowElapsed = 0
			for _, update in self._slow do
				update()
			end
		end
	end))
end

function Watermark:_addLive(list, props, update)
	local block = self:AddBlock(props)
	block._updater = { list = list, fn = function()
		block:SetText(update())
	end }
	table.insert(list, block._updater.fn)
	block._updater.fn()
	self:_startTicker()
	return block
end

-- Frames per second, updated twice a second.
function Watermark:AddFPS(props)
	props = props or {}
	return self:_addLive(self._fast, { Icon = props.Icon or "speed", IconColor = props.IconColor }, function()
		return if self.FPS then `{self.FPS} FPS` else "-- FPS"
	end)
end

-- Network ping in ms (the value the Roblox dev console shows).
function Watermark:AddPing(props)
	props = props or {}
	return self:_addLive(self._slow, { Icon = props.Icon or "wifi", IconColor = props.IconColor }, function()
		local ping = HUD.GetPing()
		return if ping then `{math.round(ping)} ms` else "-- ms"
	end)
end

-- Local time; `format` is an os.date format (default "%H:%M:%S").
function Watermark:AddClock(format: string?)
	return self:_addLive(self._slow, { Icon = "schedule" }, function()
		return os.date(format or "%H:%M:%S")
	end)
end

function Watermark:SetVisible(visible: boolean)
	self.Instance.Visible = visible
end

function Watermark:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	for _, block in table.clone(self._blocks) do
		block:Destroy()
	end
	self._maid:Destroy()
	self.Instance:Destroy()
end

function Block:SetText(text)
	self._label.Text = tostring(text)
end

function Block:GetText(): string
	return self._label.Text
end

function Block:SetIcon(name)
	local themer = self._watermark._window._themer
	if self._icon then
		self._icon:Destroy()
	end
	self._icon = makeIcon(themer, name, 16, self._iconColor, self.Instance, 1)
end

-- A theme role ("Primary", "Error", ...) or a Color3.
function Block:SetIconColor(color)
	self._iconColor = color
	if self._icon then
		bindIconColor(self._watermark._window._themer, self._icon, color)
	end
end

function Block:SetTextColor(color)
	self._watermark._window._themer:Bind(self._label, { TextColor3 = color })
end

function Block:SetVisible(visible: boolean)
	self._visible = visible
	self.Instance.Visible = visible
	self._watermark:_refreshSeparators()
end

-- Runs `fn` when the block is clicked (without dragging).
function Block:OnClick(fn)
	table.insert(self._callbacks, fn)
end
Block.Input = Block.OnClick -- NeverLose-style name

function Block:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	local watermark = self._watermark
	if self._updater then
		local index = table.find(self._updater.list, self._updater.fn)
		if index then
			table.remove(self._updater.list, index)
		end
	end
	local index = table.find(watermark._blocks, self)
	if index then
		table.remove(watermark._blocks, index)
	end
	self._maid:Destroy()
	self._separator:Destroy()
	self.Instance:Destroy()
	watermark:_refreshSeparators()
end

function HUD.GetPing(): number?
	local ok, value = pcall(function()
		return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	if ok and type(value) == "number" then
		return value
	end
	ok, value = pcall(function()
		return Players.LocalPlayer:GetNetworkPing() * 1000
	end)
	if ok and type(value) == "number" then
		return value
	end
	return nil
end

--== Keybind list ==--

local KeybindList = {}
KeybindList.__index = KeybindList

--[[
	Window:AddKeybindList({
		Title = "Keybinds",
		Position = "Left",     -- preset name or UDim2
		ShowAll = false,       -- false: only keybinds switched on (Toggle) or held (Hold)
		                       -- true: every bound keybind, active ones highlighted
		Width = 200,
	})
]]
function HUD.KeybindList(window, props)
	props = props or {}
	local themer = window._themer
	local self = setmetatable({
		_window = window,
		_showAll = props.ShowAll == true,
		_visible = props.Visible ~= false,
		_maid = Maid.new(),
	}, KeybindList)

	local frame = surface(themer, "Frame", {
		Name = "Keybinds",
		BorderSizePixel = 0,
		Active = true,
		Size = UDim2.fromOffset(props.Width or 200, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		[1] = Create("UIPadding") {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 12),
		},
		[2] = Create("UIListLayout") {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		},
	})
	Shape.Corner(Shape.Medium, frame)
	place(frame, props.Position, "Left")
	frame.Parent = HUD.Layer(window)
	self.Instance = frame

	local header = Create("Frame") {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 1,
		[1] = Create("UIListLayout") {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		},
		Parent = frame,
	}
	makeIcon(themer, props.Icon or "keyboard", 18, "IconAccent", header, 1)
	local title = Create("TextLabel") {
		Name = "Title",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -26, 1, 0),
		Text = props.Title or "Keybinds",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 2,
		Parent = header,
	}
	Typography.Apply(title, "TitleSmall")
	themer:Bind(title, { TextColor3 = "OnSurface" })
	self._title = title

	local divider = Create("Frame") {
		Name = "Divider",
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = 2,
		Parent = frame,
	}
	themer:Bind(divider, { BackgroundColor3 = "OutlineVariant" })

	self._rows = Create("Frame") {
		Name = "Rows",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		[1] = Create("UIListLayout") {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		},
		Parent = frame,
	}

	makeDraggable(self._maid, frame, frame)
	self._maid:GiveTask(window.KeybindsChanged:Connect(function()
		self:_render()
	end))
	window._maid:GiveTask(self)
	self:_render()
	return self
end

local function keybindTitle(keybind): string
	return (keybind._title and keybind._title.Text ~= "" and keybind._title.Text) or keybind.Flag or "Keybind"
end

function KeybindList:_entries()
	local entries = {}
	for _, keybind in self._window._keybinds do
		if keybind.Value and (self._showAll or keybind.State) then
			table.insert(entries, keybind)
		end
	end
	table.sort(entries, function(a, b)
		return keybindTitle(a) < keybindTitle(b)
	end)
	return entries
end

function KeybindList:_render()
	if self._destroyed or self._window._destroyed then
		return
	end
	local themer = self._window._themer
	for _, child in self._rows:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local entries = self:_entries()
	for index, keybind in entries do
		local active = keybind.State == true
		local row = Create("Frame") {
			Name = keybindTitle(keybind),
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 22),
			LayoutOrder = index,
			Parent = self._rows,
		}
		local name = Create("TextLabel") {
			Name = "Name",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -72, 1, 0),
			Text = keybindTitle(keybind),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		}
		Typography.Apply(name, "BodyMedium")
		themer:Bind(name, { TextColor3 = if active or not self._showAll then "OnSurface" else "OnSurfaceVariant" })

		local key = Create("TextLabel") {
			Name = "Key",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(0, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			BorderSizePixel = 0,
			Text = keybind.Value.Name,
			Parent = row,
			[1] = Create("UIPadding") { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) },
		}
		Shape.Corner(Shape.Small, key)
		Typography.Apply(key, "LabelMedium")
		themer:Bind(key, {
			BackgroundColor3 = if active then "PrimaryContainer" else "SurfaceContainerHighest",
			TextColor3 = if active then "OnPrimaryContainer" else "OnSurfaceVariant",
		})
	end

	if #entries == 0 and self._showAll then
		local empty = Create("TextLabel") {
			Name = "Empty",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 20),
			Text = "No keybinds",
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = self._rows,
		}
		Typography.Apply(empty, "BodyMedium")
		themer:Bind(empty, { TextColor3 = "OnSurfaceVariant" })
	end

	self.Count = #entries
	-- Active-only lists disappear when nothing is on, like a real HUD.
	self.Instance.Visible = self._visible and (self._showAll or #entries > 0)
end

function KeybindList:SetVisible(visible: boolean)
	self._visible = visible
	self:_render()
end

function KeybindList:SetShowAll(showAll: boolean)
	self._showAll = showAll
	self:_render()
end

function KeybindList:SetTitle(text: string)
	self._title.Text = text
end

function KeybindList:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._maid:Destroy()
	self.Instance:Destroy()
end

--== Indicators ==--

local Indicator = {}
Indicator.__index = Indicator

-- All indicators share one draggable stack (bottom-left by default).
local function indicatorStack(window, position)
	if window._hudIndicators then
		return window._hudIndicators
	end
	local stack = Create("Frame") {
		Name = "Indicators",
		BackgroundTransparency = 1,
		Active = true,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		[1] = Create("UIListLayout") {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		},
	}
	place(stack, position, "BottomLeft")
	stack.Parent = HUD.Layer(window)
	local maid = Maid.new()
	makeDraggable(maid, stack, stack)
	window._maid:GiveTask(maid)
	window._hudIndicators = stack
	window._hudIndicatorCount = 0
	return stack
end

--[[
	Window:AddIndicator({
		Text = "AUTO",
		Icon = "bolt",             -- Material icon name or image; optional
		Color = "Primary",         -- theme role or Color3 (text + icon)
		Visible = true,
		Position = "BottomLeft",   -- only the first indicator's Position is used (they share a stack)
	})
]]
function HUD.Indicator(window, props)
	props = props or {}
	local themer = window._themer
	local stack = indicatorStack(window, props.Position)
	window._hudIndicatorCount += 1
	local self = setmetatable({ _window = window, _color = props.Color or "Primary", _maid = Maid.new() }, Indicator)

	local chip = surface(themer, "Frame", {
		Name = props.Text or "Indicator",
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = window._hudIndicatorCount,
		Visible = props.Visible ~= false,
		[1] = Create("UIPadding") { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14) },
		[2] = Create("UIListLayout") {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		},
		Parent = stack,
	})
	Shape.Corner(Shape.Full, chip)
	self.Instance = chip

	local label = Create("TextLabel") {
		Name = "Text",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = tostring(props.Text or ""),
		LayoutOrder = 2,
		Parent = chip,
	}
	Typography.Apply(label, "LabelLarge")
	themer:Bind(label, { TextColor3 = self._color })
	self._label = label
	self._icon = makeIcon(themer, props.Icon, 16, self._color, chip, 1)

	-- Dragging an indicator moves the whole stack.
	makeDraggable(self._maid, chip, stack)
	window._maid:GiveTask(self)
	return self
end

function Indicator:SetText(text)
	self._label.Text = tostring(text)
end

function Indicator:GetText(): string
	return self._label.Text
end

function Indicator:SetIcon(name)
	if self._icon then
		self._icon:Destroy()
	end
	self._icon = makeIcon(self._window._themer, name, 16, self._color, self.Instance, 1)
end

-- A theme role ("Primary", "Error", "Tertiary", ...) or a Color3.
function Indicator:SetColor(color)
	self._color = color
	local themer = self._window._themer
	themer:Bind(self._label, { TextColor3 = color })
	if self._icon then
		bindIconColor(themer, self._icon, color)
	end
end

function Indicator:SetVisible(visible: boolean)
	self.Instance.Visible = visible
end
Indicator.SetRender = Indicator.SetVisible -- NeverLose-style name

function Indicator:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._maid:Destroy()
	self.Instance:Destroy()
end

return HUD
