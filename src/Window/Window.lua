--[[
	Executor-style window built from MD3 components.

	local Window = MD3:CreateWindow({
		Title = "My Hub",
		Subtitle = "v1.0",
		Icon = "widgets",                  -- Material icon name, or an image (URL / rbxassetid)
		ThemeColor = Color3.fromHex("#6750A4"), -- theme (seed) color the palette is generated from
		IconColor = nil,                   -- color of every icon (Color3); default follows the theme
		TextColor = nil,                   -- color of all text (Color3); secondary text follows it
		AppIconColor = nil,                -- just the title-bar icon: theme role or Color3
		Logo = "https://.../logo.png",     -- colored image shown instead of Icon (not tinted)
		Size = UDim2.fromOffset(600, 420),  -- starting size; drag the bottom-right corner to resize
		RememberSize = true,               -- restore the size the user dragged to last time
		Mode = "Dark",                     -- "Light" | "Dark"
		Seed = nil,                        -- same as ThemeColor
		ToggleKey = Enum.KeyCode.RightShift,
		ConfigFolder = "MyHub",            -- where configs are saved (executor workspace)
		Icons = true,                      -- load the Material icon images (false = BuilderIcons / symbols only)
		IconStyle = "Outlined",            -- "Outlined" (default) | "Filled" | "Round" | "Sharp"
		MobileButton = nil,                -- floating open/close button; default: on touch devices
	})

	local Main = Window:AddTab({ Title = "Main", Icon = "home" })
	Main:AddToggle({ Title = "Auto farm", Flag = "AutoFarm", Callback = function(on) end })

	Window:Notify({ Title = "Loaded", Content = "Press RightShift to hide", Icon = "check_circle" })

	-- HUD (stays up while the window is hidden)
	Window:AddWatermark({ FPS = true, Ping = true, Clock = true })
	Window:AddKeybindList()
	Window:AddIndicator({ Text = "AUTO", Icon = "bolt" })
]]
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Root = script.Parent.Parent
local Create = require(Root.Util.Create)
local Maid = require(Root.Util.Maid)
local Signal = require(Root.Util.Signal)
local Theme = require(Root.Core.Theme)
local Typography = require(Root.Core.Typography)
local Shape = require(Root.Core.Shape)
local Motion = require(Root.Core.Motion)
local Elevation = require(Root.Core.Elevation)
local StateLayer = require(Root.Core.StateLayer)
local Icons = require(Root.Core.Icons)
local Dialog = require(Root.Components.Dialog)
local Env = require(Root.Executor.Env)
local IconImages = require(Root.Executor.IconImages)
local Themer = require(script.Parent.Themer)
local Config = require(script.Parent.Config)
local Notifier = require(script.Parent.Notifier)
local Tab = require(script.Parent.Tab)
local Base = require(script.Parent.Elements.Base)
local makeDraggable = require(script.Parent.Draggable)
local HUD = require(script.Parent.HUD)

local TOP_BAR_HEIGHT = 56
local NAV_WIDTH = 168
local DEFAULT_SIZE = UDim2.fromOffset(600, 420)
local MIN_SIZE = Vector2.new(420, 280) -- smallest size the resize handle allows

local Window = {}
Window.__index = Window

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local function toKeyCode(value)
	if typeof(value) == "EnumItem" then
		return value
	elseif type(value) == "string" then
		local ok, key = pcall(function()
			return (Enum.KeyCode :: any)[value]
		end)
		return ok and key or nil
	end
	return nil
end

local function sanitize(name: string): string
	return (tostring(name):gsub("[^%w%-_ ]", ""))
end

function Window.new(props)
	props = props or {}
	local self = setmetatable({}, Window)
	self.Title = props.Title or props.Name or "MD3"
	self.Flags = {}
	self.Tabs = {}
	self.SelectedTab = nil
	self.Visible = true
	self.Minimized = false
	self.OnUnload = Signal.new()
	-- Every Keybind element, and a signal fired when one is added, removed,
	-- rebound or switched on/off (drives the HUD keybind list).
	self._keybinds = {}
	self.KeybindsChanged = Signal.new()
	self._maid = Maid.new()
	self._toggleKey = toKeyCode(props.ToggleKey or props.Keybind) or Enum.KeyCode.RightShift
	self._size = props.Size or DEFAULT_SIZE
	self._defaultSize = self._size
	self._rememberSize = props.RememberSize ~= false

	-- Replace the window a previous run of the same script left behind.
	local registry = Env.Registry()
	registry.Windows = registry.Windows or {}
	self._registryKey = props.Id or self.Title
	local previous = registry.Windows[self._registryKey]
	if previous and previous ~= self and props.ReplaceExisting ~= false then
		pcall(previous.Destroy, previous)
	end
	registry.Windows[self._registryKey] = self

	self._configFolder = props.ConfigFolder or props.Folder or `MD3/{sanitize(self.Title)}`

	-- The size the user resized the window to last time (window.json).
	if self._rememberSize then
		local saved = self:_readSavedSize()
		if saved then
			self._size = UDim2.fromOffset(saved.X, saved.Y)
		end
	end

	-- Material icons as a sprite-sheet image, loaded the way NeverLose loads
	-- its images (HttpGet -> writefile -> getcustomasset). Runs in the
	-- background so the window appears immediately; icons start out as
	-- BuilderIcons / symbols and switch over in place once it's ready. An
	-- explicit IconStyle always (re)loads; otherwise keep what's loaded.
	if props.Icons ~= false and props.IconFont ~= false and (props.IconStyle ~= nil or not Icons.GetSheet()) then
		task.spawn(function()
			local ok, err = IconImages.Load(props.IconStyle)
			if not ok and Env.CanUseCustomAssets then
				warn(`[MD3] could not load the icon images: {err}`)
			end
		end)
	end

	self.Theme = props.Theme or Theme.new(props.ThemeColor or props.Seed or props.Accent, props.Mode or "Dark")
	if props.TextColor then
		self.Theme:SetTextColor(props.TextColor)
	end
	if props.IconColor then
		self.Theme:SetIconColor(props.IconColor)
	end
	self._themer = Themer.new(self.Theme)
	local themer = self._themer

	--== ScreenGui ==--
	local gui = Create("ScreenGui") {
		Name = props.GuiName or Env.RandomName(),
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = props.DisplayOrder or 100,
	}
	Env.ProtectGui(gui)
	gui.Parent = props.Parent or Env.GetGuiParent()
	self.Gui = gui

	--== Main surface ==--
	local main = Create("Frame") {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = self._size,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Active = true,
		Parent = gui,
	}
	Shape.Corner(Shape.Large, main)
	themer:Bind(main, { BackgroundColor3 = "Surface" })
	themer:Bind(Create("UIStroke") {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 1,
		Parent = main,
	}, { Color = "OutlineVariant" })
	local uiScale = Create("UIScale") { Parent = main }
	self.Instance = main
	self._uiScale = uiScale

	-- The shadow is a sibling of `main`, outside its UIScale, so it gets its
	-- own UIScale kept in sync (otherwise it stays full size on phones).
	local shadowScale = nil
	local function applyShadow()
		local holder = Elevation.Apply(main, 3, self.Theme.Colors.Shadow, Shape.Large)
		shadowScale = holder and Create("UIScale") { Scale = uiScale.Scale, Parent = holder }
	end
	applyShadow()
	self._maid:GiveTask(self.Theme.Changed:Connect(applyShadow))
	self._maid:GiveTask(uiScale:GetPropertyChangedSignal("Scale"):Connect(function()
		if shadowScale then
			shadowScale.Scale = uiScale.Scale
		end
	end))

	--== Top app bar ==--
	local topBar = Create("Frame") {
		Name = "TopBar",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TOP_BAR_HEIGHT),
		Active = true,
		Parent = main,
	}

	-- Logo = a colored image kept as-is; Icon = a tinted Material icon or image.
	local appIconSource = props.Logo or props.Icon
	local hasAppIcon = appIconSource ~= nil and Base.CanShowIcon(appIconSource)
	self._appIconSource = appIconSource -- reused by the HUD watermark
	self._appIconTint = props.Logo == nil
	if hasAppIcon then
		local appIcon = Base.Glyph(themer, appIconSource, 24, props.AppIconColor or "IconAccent", topBar, props.Logo == nil)
		appIcon.AnchorPoint = Vector2.new(0, 0.5)
		appIcon.Position = UDim2.new(0, 20, 0.5, 0)
		-- A glyph may still be waiting for the icon images; a failed image won't come back.
		if appIcon:IsA("ImageLabel") and not appIcon.Visible then
			appIcon:Destroy()
			hasAppIcon = false
		end
	end

	local titleColumn = Create("Frame") {
		Name = "Titles",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(hasAppIcon and 56 or 20, 0),
		Size = UDim2.new(1, -(hasAppIcon and 56 or 20) - 96, 1, 0),
		Parent = topBar,
		[1] = Create("UIListLayout") {
			FillDirection = Enum.FillDirection.Vertical,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
	}
	local title = Create("TextLabel") {
		Name = "Title",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		Text = self.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 1,
		Parent = titleColumn,
	}
	Typography.Apply(title, "TitleMedium")
	themer:Bind(title, { TextColor3 = "OnSurface" })
	self._titleLabel = title

	local subtitle = Create("TextLabel") {
		Name = "Subtitle",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		Text = props.Subtitle or "",
		Visible = (props.Subtitle or "") ~= "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 2,
		Parent = titleColumn,
	}
	Typography.Apply(subtitle, "BodySmall")
	themer:Bind(subtitle, { TextColor3 = "OnSurfaceVariant" })
	self._subtitleLabel = subtitle

	local actions = Create("Frame") {
		Name = "Actions",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(80, 36),
		Parent = topBar,
		[1] = Create("UIListLayout") {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		},
	}

	local function barButton(iconName: string, order: number, onActivated)
		local button = Create("TextButton") {
			Name = iconName,
			AutoButtonColor = false,
			Text = "",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(36, 36),
			LayoutOrder = order,
			Parent = actions,
		}
		Shape.Corner(Shape.Full, button)
		local glyph = Base.Glyph(themer, iconName, 20, "Icon", button)
		glyph.AnchorPoint = Vector2.new(0.5, 0.5)
		glyph.Position = UDim2.fromScale(0.5, 0.5)
		local layer = StateLayer.new(button, self.Theme.Colors.OnSurfaceVariant, Shape.Full)
		themer:Bind(layer.Instance, { BackgroundColor3 = "OnSurfaceVariant" })
		self._maid:GiveTask(button.MouseEnter:Connect(function()
			layer:SetState("Hover", true)
		end))
		self._maid:GiveTask(button.MouseLeave:Connect(function()
			layer:SetState("Hover", false)
		end))
		self._maid:GiveTask(button.Activated:Connect(onActivated))
		return button
	end

	barButton("minimize", 1, function()
		self:Minimize()
	end)
	barButton("close", 2, function()
		self:_confirmClose()
	end)

	makeDraggable(self._maid, topBar, main)

	--== Body: navigation drawer + content ==--
	local body = Create("Frame") {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, TOP_BAR_HEIGHT),
		Size = UDim2.new(1, 0, 1, -TOP_BAR_HEIGHT),
		Parent = main,
	}
	self._body = body

	local navList = Create("ScrollingFrame") {
		Name = "Navigation",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, NAV_WIDTH, 1, 0),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = body,
		[1] = Create("UIPadding") {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
		},
		[2] = Create("UIListLayout") {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		},
	}
	self._navList = navList

	local pages = Create("Frame") {
		Name = "Pages",
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(NAV_WIDTH, 0),
		Size = UDim2.new(1, -NAV_WIDTH - 12, 1, -12),
		ClipsDescendants = true,
		Parent = body,
	}
	Shape.Corner(Shape.Large, pages)
	themer:Bind(pages, { BackgroundColor3 = "SurfaceContainerLow" })
	self._pages = pages

	--== Resize handle (bottom-right corner) ==--
	local grip = Create("TextButton") {
		Name = "Resize",
		AutoButtonColor = false,
		Text = "",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(28, 28),
		ZIndex = 20,
		Parent = main,
	}
	-- Two diagonal strokes, the usual "drag to resize" grip: a long one and
	-- a short one nearer the corner.
	for _, spec in { { length = 12, inset = 11 }, { length = 6, inset = 7 } } do
		local stroke = Create("Frame") {
			Name = "Stroke",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -spec.inset, 1, -spec.inset),
			Size = UDim2.fromOffset(spec.length, 2),
			Rotation = -45,
			BorderSizePixel = 0,
			ZIndex = 21,
			Parent = grip,
			[1] = Create("UICorner") { CornerRadius = UDim.new(1, 0) },
		}
		themer:Bind(stroke, { BackgroundColor3 = "Outline" })
	end
	self._grip = grip

	do
		local resizing, startInput, startSize, startPos = false, nil, nil, nil
		self._maid:GiveTask(grip.InputBegan:Connect(function(input)
			if isPress(input) and not self.Minimized then
				resizing = true
				startInput = input.Position
				startSize = Vector2.new(self._size.X.Offset, self._size.Y.Offset)
				startPos = main.Position
			end
		end))
		self._maid:GiveTask(UserInputService.InputChanged:Connect(function(input)
			if not resizing or not isMove(input) then
				return
			end
			-- Screen pixels -> unscaled window pixels (UIScale shrinks it on phones).
			local scale = uiScale.Scale
			local delta = (input.Position - startInput) / scale
			local camera = workspace.CurrentCamera
			local viewport = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
			local width = math.clamp(startSize.X + delta.X, MIN_SIZE.X, math.max(MIN_SIZE.X, viewport.X / scale - 24))
			local height = math.clamp(startSize.Y + delta.Y, MIN_SIZE.Y, math.max(MIN_SIZE.Y, viewport.Y / scale - 24))
			self._size = UDim2.fromOffset(math.round(width), math.round(height))
			main.Size = self._size
			-- The window is centered on its Position; move it by half the growth
			-- so the top-left corner stays put and the grip follows the pointer.
			main.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + (width - startSize.X) * scale / 2,
				startPos.Y.Scale,
				startPos.Y.Offset + (height - startSize.Y) * scale / 2
			)
		end))
		self._maid:GiveTask(UserInputService.InputEnded:Connect(function(input)
			if resizing and isPress(input) then
				resizing = false
				self:_saveSize()
			end
		end))
	end

	--== Notifications ==--
	self._notifier = Notifier.new(gui, themer)

	--== Floating open/close button (for touch devices without a keyboard) ==--
	local showMobileButton = props.MobileButton
	if showMobileButton == nil then
		showMobileButton = UserInputService.TouchEnabled
	end
	if showMobileButton then
		local mobileButton = Create("TextButton") {
			Name = "Toggle",
			AutoButtonColor = false,
			Text = "",
			Position = UDim2.new(0, 16, 0.3, 0),
			Size = UDim2.fromOffset(48, 48),
			BorderSizePixel = 0,
			ZIndex = 60,
			Parent = gui,
		}
		Shape.Corner(Shape.Large, mobileButton)
		themer:Bind(mobileButton, { BackgroundColor3 = "PrimaryContainer" })
		local source = props.Logo or (props.Icon and Base.CanShowIcon(props.Icon) and props.Icon) or "menu"
		local glyph = Base.Glyph(themer, source, props.Logo and 32 or 24, "OnPrimaryContainer", mobileButton, props.Logo == nil)
		glyph.AnchorPoint = Vector2.new(0.5, 0.5)
		glyph.Position = UDim2.fromScale(0.5, 0.5)
		glyph.ZIndex = 61
		makeDraggable(self._maid, mobileButton, mobileButton, function()
			self:Toggle()
		end)
		self._mobileButton = mobileButton
	end

	--== Input: toggle key ==--
	self._maid:GiveTask(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or UserInputService:GetFocusedTextBox() or self:_isCapturingKey(input) then
			return
		end
		if self._toggleKey and input.KeyCode == self._toggleKey then
			self:Toggle()
		end
	end))

	--== Fit small screens (phones) ==--
	local function rescale()
		if props.Scale then
			uiScale.Scale = props.Scale
			return
		end
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
		local fit = math.min(1, (viewport.X - 24) / self._size.X.Offset, (viewport.Y - 24) / self._size.Y.Offset)
		uiScale.Scale = math.max(fit, 0.4)
	end
	rescale()
	local camera = workspace.CurrentCamera
	if camera then
		self._maid:GiveTask(camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale))
	end

	return self
end

--== Internal helpers ==--

-- Runs a user callback without letting its errors break the UI.
function Window:_call(fn, ...)
	task.spawn(function(...)
		local ok, err = xpcall(fn, debug.traceback, ...)
		if not ok then
			warn(`[MD3] {self.Title}: callback error: {err}`)
		end
	end, ...)
end

-- True while a Keybind element is waiting for (or has just consumed) this
-- key press, so rebinding a key doesn't also trigger whatever it's bound to.
-- Matched by key + time rather than InputObject identity, since Roblox may
-- reuse InputObjects between presses.
function Window:_isCapturingKey(input): boolean
	if self._keybindListening then
		return true
	end
	return input ~= nil
		and self._capturedKey ~= nil
		and input.KeyCode == self._capturedKey
		and os.clock() - self._capturedAt < 0.1
end

function Window:_confirmClose()
	self:Dialog({
		Title = "Close window?",
		Content = `Hide keeps the script running (press {self._toggleKey and self._toggleKey.Name or "the toggle key"} to reopen). Unload destroys the UI.`,
		Buttons = {
			{ Title = "Cancel", Variant = "Text" },
			{
				Title = "Unload",
				Variant = "Text",
				Callback = function()
					self:Destroy()
				end,
			},
			{
				Title = "Hide",
				Variant = "Filled",
				Callback = function()
					self:SetVisible(false)
				end,
			},
		},
	})
end

--== Tabs ==--

function Window:AddTab(props)
	local tab = Tab.new(self, props)
	table.insert(self.Tabs, tab)
	if not self.SelectedTab then
		self:SelectTab(tab)
	end
	return tab
end
Window.CreateTab = Window.AddTab

-- Accepts a Tab, its index, or its title.
function Window:SelectTab(target)
	local tab = target
	if type(target) == "number" then
		tab = self.Tabs[target]
	elseif type(target) == "string" then
		for _, candidate in self.Tabs do
			if candidate.Title == target then
				tab = candidate
			end
		end
	end
	if type(tab) ~= "table" or tab == self.SelectedTab then
		return
	end
	local previous = self.SelectedTab
	self.SelectedTab = tab
	if previous then
		previous:_setActive(false)
	end
	tab:_setActive(true)
end

--== Visibility ==--

function Window:SetVisible(visible: boolean)
	self.Visible = visible
	local main = self.Instance
	if visible then
		main.Visible = true
		local target = self._uiScale.Scale
		self._uiScale.Scale = target * 0.94
		TweenService:Create(self._uiScale, Motion.Emphasized(Motion.Duration.Medium2), { Scale = target }):Play()
	else
		main.Visible = false
	end
end

function Window:Toggle()
	self:SetVisible(not self.Visible)
end

function Window:Minimize(minimized: boolean?)
	if minimized == nil then
		minimized = not self.Minimized
	end
	self.Minimized = minimized
	local main = self.Instance
	local ti = Motion.Emphasized(Motion.Duration.Medium2)
	self._grip.Visible = not minimized

	local targetSize = if minimized
		then UDim2.new(self._size.X.Scale, self._size.X.Offset, 0, TOP_BAR_HEIGHT)
		else self._size
	-- `main` is anchored at its center, so resizing alone would collapse and
	-- expand around the middle. Shift the center by half the height change
	-- (in screen pixels, hence the UIScale) so the top bar stays put: the
	-- window folds up into its title bar and unfolds downward. Measured from
	-- the current size so an interrupted tween stays anchored too.
	local heightDelta = (targetSize.Y.Offset - main.Size.Y.Offset) * self._uiScale.Scale
	local position = main.Position
	local targetPosition = UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset + heightDelta / 2)

	if not minimized then
		self._body.Visible = true
	end
	local tween = TweenService:Create(main, ti, { Size = targetSize, Position = targetPosition })
	tween:Play()
	if minimized then
		tween.Completed:Once(function()
			if self.Minimized then
				self._body.Visible = false
			end
		end)
	end
end

-- Switches the Material icon style ("Outlined" | "Filled" | "Round" |
-- "Sharp") live; every icon already on screen is redrawn. Returns the style
-- actually shown afterwards (unchanged if loading failed) and the error.
function Window:SetIconStyle(style: string): (string?, string?)
	local ok, err = IconImages.Load(style)
	if not ok then
		return IconImages.CurrentStyle, err
	end
	return IconImages.CurrentStyle
end

-- Resizes the window (unscaled pixels; the resize handle does the same).
-- Accepts a UDim2 offset size or width, height numbers.
function Window:SetSize(width, height: number?)
	if type(width) ~= "number" then -- a UDim2
		width, height = width.X.Offset, width.Y.Offset
	end
	self._size = UDim2.fromOffset(math.max(width, MIN_SIZE.X), math.max(height, MIN_SIZE.Y))
	if not self.Minimized then
		self.Instance.Size = self._size
	end
	self:_saveSize()
end

function Window:GetSize(): UDim2
	return self._size
end

-- Back to the size given in CreateWindow (or the default).
function Window:ResetSize()
	self:SetSize(self._defaultSize)
end

function Window:_sizePath(): string
	return `{self._configFolder}/window.json`
end

function Window:_saveSize()
	if not (self._rememberSize and Env.CanUseFiles) then
		return
	end
	Env.MakeFolder(self._configFolder)
	Env.WriteFile(self:_sizePath(), HttpService:JSONEncode({
		Width = self._size.X.Offset,
		Height = self._size.Y.Offset,
	}))
end

function Window:_readSavedSize(): Vector2?
	local json = Env.ReadFile(self:_sizePath())
	if not json then
		return nil
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
	if ok and type(data) == "table" and type(data.Width) == "number" and type(data.Height) == "number" then
		return Vector2.new(math.max(data.Width, MIN_SIZE.X), math.max(data.Height, MIN_SIZE.Y))
	end
	return nil
end

function Window:SetToggleKey(key)
	self._toggleKey = toKeyCode(key)
end

function Window:SetTitle(text: string)
	self.Title = text
	self._titleLabel.Text = text
end

function Window:SetSubtitle(text: string?)
	self._subtitleLabel.Text = text or ""
	self._subtitleLabel.Visible = (text or "") ~= ""
end

--== Feedback ==--

-- Notify({ Title, Content, Icon = "info", Duration = 5 })
function Window:Notify(props)
	return self._notifier:Notify(props)
end

-- Dialog({ Title, Content, Buttons = { { Title, Variant = "Filled", Callback } } })
function Window:Dialog(props)
	local actions = {}
	for _, button in props.Buttons or props.Actions or { { Title = "OK", Variant = "Filled" } } do
		table.insert(actions, {
			Text = button.Title or button.Text or "OK",
			Variant = button.Variant or "Text",
			OnActivated = button.Callback and function()
				self:_call(button.Callback)
			end,
		})
	end
	local dialog = Dialog.new({
		Parent = self.Instance,
		Title = props.Title or "",
		Text = props.Content or props.Text or "",
		Actions = actions,
		Theme = self.Theme,
		ZIndex = 100,
	})
	Shape.Corner(Shape.Large, dialog.Instance)
	dialog.Dismissed:Connect(function()
		dialog:Destroy()
	end)
	dialog:Show()
	return dialog
end

--== HUD (stays on screen while the window is hidden; see HUD.lua) ==--

-- AddWatermark({ Title, Icon, Position = "TopLeft", FPS, Ping, Clock })
function Window:AddWatermark(props)
	return HUD.Watermark(self, props)
end

-- AddKeybindList({ Title = "Keybinds", Position = "Left", ShowAll = false })
function Window:AddKeybindList(props)
	return HUD.KeybindList(self, props)
end

-- AddIndicator({ Text, Icon, Color = "Primary" })
function Window:AddIndicator(props)
	return HUD.Indicator(self, props)
end

function Window:SetHUDVisible(visible: boolean)
	HUD.Layer(self).Visible = visible
end

-- HUD transparency (0 = solid, 1 = invisible), separate from the window's:
-- `background` for fills and outlines, `text` for text and icons. nil leaves
-- that part as it is. Stored as the theme's HUDBackground / HUDText
-- transparency, so it's saved in configs and theme exports.
function Window:SetHUDTransparency(background: number?, text: number?)
	local transparency = self.Theme:GetTransparencies()
	if background ~= nil then
		transparency.HUDBackground = background
	end
	if text ~= nil then
		transparency.HUDText = text
	end
	self.Theme:SetOverrides(self.Theme:GetOverrides(), transparency)
end

function Window:GetHUDTransparency(): (number, number)
	return self.Theme:GetTransparency("HUDBackground") or 0, self.Theme:GetTransparency("HUDText") or 0
end

--== Configs ==--

function Window:CanSaveConfigs(): boolean
	return Env.CanUseFiles
end

function Window:_configPath(name: string): string
	return `{self._configFolder}/configs/{sanitize(name)}.json`
end

function Window:SaveConfig(name: string?): (boolean, string?)
	if not Env.CanUseFiles then
		return false, "this executor has no file functions"
	end
	name = name or "default"
	Env.MakeFolder(`{self._configFolder}/configs`)
	local ok = Env.WriteFile(self:_configPath(name), Config.Encode(self.Flags))
	return ok, (not ok) and "writefile failed" or nil
end

function Window:LoadConfig(name: string?): (boolean, string?)
	name = name or "default"
	local json = Env.ReadFile(self:_configPath(name))
	if not json then
		return false, `config "{name}" not found`
	end
	local data = Config.Decode(json)
	if not data then
		return false, `config "{name}" is corrupted`
	end
	for flag, value in data do
		local element = self.Flags[flag]
		if element then
			local ok, err = pcall(element.Set, element, value)
			if not ok then
				warn(`[MD3] could not load flag {flag}: {err}`)
			end
		end
	end
	return true
end

function Window:DeleteConfig(name: string): boolean
	return Env.DeleteFile(self:_configPath(name))
end

function Window:ListConfigs(): { string }
	local names = {}
	for _, path in Env.ListFiles(`{self._configFolder}/configs`) do
		local name = tostring(path):match("([^/\\]+)%.json$")
		if name then
			table.insert(names, name)
		end
	end
	table.sort(names)
	return names
end

function Window:SetAutoLoad(name: string?)
	local path = `{self._configFolder}/autoload.txt`
	if name then
		Env.MakeFolder(self._configFolder)
		Env.WriteFile(path, sanitize(name))
	else
		Env.DeleteFile(path)
	end
end

function Window:GetAutoLoad(): string?
	local name = Env.ReadFile(`{self._configFolder}/autoload.txt`)
	return name ~= "" and name or nil
end

-- Call once at the end of your script, after every flagged element exists.
function Window:LoadAutoloadConfig(): boolean
	local name = self:GetAutoLoad()
	if not name then
		return false
	end
	local ok, err = self:LoadConfig(name)
	if ok then
		self:Notify({ Title = "Config loaded", Content = `Auto-loaded "{name}"`, Icon = "folder" })
	else
		warn(`[MD3] autoload failed: {err}`)
	end
	return ok
end
Window.LoadConfiguration = Window.LoadAutoloadConfig

--== Built-in settings tab ==--

-- Theme mode, accent color, toggle key, unload and (when the executor has
-- file functions) config save/load/delete/autoload.
function Window:AddSettingsTab(props)
	props = props or {}
	local tab = self:AddTab({ Title = props.Title or "Settings", Icon = props.Icon or "settings" })

	local appearance = tab:AddSection("Appearance")
	local darkMode = appearance:AddToggle({
		Title = "Dark mode",
		Default = self.Theme.Mode == "Dark",
		Flag = "MD3_DarkMode",
		Callback = function(on)
			self.Theme:SetMode(on and "Dark" or "Light")
		end,
	})
	local accent = appearance:AddColorPicker({
		Title = "Theme color",
		Description = "The whole palette is generated from this color",
		Default = self.Theme.Seed,
		Flag = "MD3_Accent",
		Callback = function(color)
			self.Theme:SetSeedColor(color)
		end,
	})

	-- Icon and text color: overrides (saved with the theme editor's
	-- MD3_ThemeOverrides flag), shown as the current color when not custom.
	local quick = {
		{ Role = "Icon", Title = "Icon color", Auto = "Follows the text color" },
		{ Role = "OnSurface", Title = "Text color", Auto = "Generated from the theme color" },
	}
	local quickPickers = {}
	local editingQuick = nil
	for _, entry in quick do
		quickPickers[entry.Role] = appearance:AddColorPicker({
			Title = entry.Title,
			Default = self.Theme.Colors[entry.Role],
			Transparency = self.Theme:GetTransparency(entry.Role) or 0,
			Callback = function(color, transparency)
				editingQuick = entry.Role
				self.Theme:SetOverride(entry.Role, color, transparency)
				editingQuick = nil
			end,
		})
	end
	appearance:AddButton({
		Title = "Reset icon & text colors",
		Icon = "refresh",
		Callback = function()
			local overrides, transparency = self.Theme:GetOverrides(), self.Theme:GetTransparencies()
			for _, entry in quick do
				overrides[entry.Role], transparency[entry.Role] = nil, nil
			end
			self.Theme:SetOverrides(overrides, transparency)
		end,
	})
	local function refreshQuick()
		for _, entry in quick do
			local picker = quickPickers[entry.Role]
			local color = self.Theme.Colors[entry.Role]
			local transparency = self.Theme:GetTransparency(entry.Role) or 0
			if editingQuick ~= entry.Role and (picker.Value ~= color or picker.Transparency ~= transparency) then
				picker:Set({ Color = color, Transparency = transparency }, true)
			end
			picker:SetDescription(if self.Theme:IsOverridden(entry.Role) then "Custom" else entry.Auto)
		end
	end
	refreshQuick()
	self._maid:GiveTask(self.Theme.Changed:Connect(refreshQuick))

	-- Icon style needs file functions + getcustomasset to load the images.
	if Env.CanUseCustomAssets then
		local iconStyle
		iconStyle = appearance:AddDropdown({
			Title = "Icon style",
			Description = "Material Icons: Outlined is the M3 default",
			Options = IconImages.StyleNames,
			Default = IconImages.CurrentStyle or IconImages.DefaultStyle,
			Flag = "MD3_IconStyle",
			Callback = function(style)
				if not style then
					return
				end
				local current, err = self:SetIconStyle(style)
				if current ~= style then
					-- Show what's really on screen (the previous style, if any).
					iconStyle:Set(current, true)
					self:Notify({ Title = "Icon style unavailable", Content = err or "", Icon = "error" })
				end
			end,
		})
	end

	-- Keep these two in sync when the theme changes elsewhere (theme editor
	-- presets, imports, config loads).
	self._maid:GiveTask(self.Theme.Changed:Connect(function(theme)
		if darkMode.Value ~= (theme.Mode == "Dark") then
			darkMode:Set(theme.Mode == "Dark", true)
		end
		if accent.Value ~= theme.Seed then
			accent:Set(theme.Seed, true)
		end
	end))

	self:AddThemeEditor(tab)

	local interface = tab:AddSection("Interface")
	interface:AddKeybind({
		Title = "Toggle UI",
		Description = "Shows / hides this window",
		Default = self._toggleKey,
		Flag = "MD3_ToggleKey",
		ChangedCallback = function(key)
			self:SetToggleKey(key)
		end,
	})
	interface:AddButton({
		Title = "Reset window size",
		Description = "Drag the bottom-right corner to resize",
		Icon = "fullscreen_exit",
		Callback = function()
			self:ResetSize()
		end,
	})
	interface:AddButton({
		Title = "Unload",
		Description = "Destroys this UI",
		Icon = "close",
		Callback = function()
			self:Destroy()
		end,
	})

	-- Only when the script built some HUD before adding the settings tab.
	if self._hudLayer then
		local hud = tab:AddSection("HUD")
		hud:AddToggle({
			Title = "Show HUD",
			Description = "Watermark, keybind list and indicators",
			Default = self._hudLayer.Visible,
			Flag = "MD3_ShowHUD",
			Callback = function(on)
				self:SetHUDVisible(on)
			end,
		})
		-- Transparency lives in the theme (saved with MD3_ThemeOverrides), so
		-- these sliders have no Flag and just mirror it.
		local sliders = {
			{ Role = "HUDBackground", Title = "Background transparency", Description = "Separate from the window's" },
			{ Role = "HUDText", Title = "Text transparency", Description = "Text and icons" },
		}
		local editing = nil
		for _, entry in sliders do
			entry.Slider = hud:AddSlider({
				Title = entry.Title,
				Description = entry.Description,
				Min = 0,
				Max = 100,
				Step = 1,
				Suffix = "%",
				Default = math.round((self.Theme:GetTransparency(entry.Role) or 0) * 100),
				Callback = function(percent)
					editing = entry.Role
					if entry.Role == "HUDBackground" then
						self:SetHUDTransparency(percent / 100, nil)
					else
						self:SetHUDTransparency(nil, percent / 100)
					end
					editing = nil
				end,
			})
		end
		self._maid:GiveTask(self.Theme.Changed:Connect(function()
			for _, entry in sliders do
				local percent = math.round((self.Theme:GetTransparency(entry.Role) or 0) * 100)
				if entry.Role ~= editing and entry.Slider.Value ~= percent then
					entry.Slider:Set(percent, true)
				end
			end
		end))
	end

	if self:CanSaveConfigs() then
		local configs = tab:AddSection("Configuration")
		local nameInput = configs:AddInput({ Title = "Config name", Placeholder = "default" })
		local list = configs:AddDropdown({ Title = "Saved configs", Options = self:ListConfigs() })

		local function selectedName()
			if nameInput.Value ~= "" then
				return nameInput.Value
			end
			return list.Value or "default"
		end
		local function refresh()
			list:SetOptions(self:ListConfigs())
		end

		configs:AddButton({
			Title = "Save config",
			Icon = "save",
			Callback = function()
				local name = selectedName()
				local ok, err = self:SaveConfig(name)
				refresh()
				list:Set(name, true)
				self:Notify({ Title = ok and "Config saved" or "Save failed", Content = ok and name or err, Icon = ok and "save" or "error" })
			end,
		})
		configs:AddButton({
			Title = "Load config",
			Icon = "folder",
			Callback = function()
				local name = selectedName()
				local ok, err = self:LoadConfig(name)
				self:Notify({ Title = ok and "Config loaded" or "Load failed", Content = ok and name or err, Icon = ok and "folder" or "error" })
			end,
		})
		configs:AddButton({
			Title = "Delete config",
			Icon = "delete",
			Callback = function()
				local name = selectedName()
				self:DeleteConfig(name)
				refresh()
				self:Notify({ Title = "Config deleted", Content = name, Icon = "delete" })
			end,
		})
		local autoload
		autoload = configs:AddButton({
			Title = "Set as autoload",
			Description = `Current: {self:GetAutoLoad() or "none"}`,
			Icon = "bolt",
			Callback = function()
				local name = selectedName()
				self:SetAutoLoad(name)
				autoload:SetDescription(`Current: {name}`)
				self:Notify({ Title = "Autoload set", Content = name, Icon = "bolt" })
			end,
		})
		configs:AddButton({
			Title = "Clear autoload",
			Icon = "block",
			Callback = function()
				self:SetAutoLoad(nil)
				autoload:SetDescription("Current: none")
			end,
		})
	end

	return tab
end

--== Theme editor ==--

-- Adds a theme editor to `container` (a Tab or Section; default: a new
-- "Theme" tab): palette presets, a color picker for each editable color
-- role (Theme.EditableRoles, icon colors included), reset, and copy /
-- import as JSON. Custom colors are theme overrides on top of the seed
-- palette, saved in configs under the flag MD3_ThemeOverrides.
function Window:AddThemeEditor(container)
	local theme = self.Theme
	container = container or self:AddTab({ Title = "Theme", Icon = "palette" })
	local section = if container.AddSection then container:AddSection("Theme editor") else container

	local presetNames = {}
	for _, preset in Theme.Presets do
		table.insert(presetNames, preset.Name)
	end
	section:AddDropdown({
		Title = "Preset",
		Description = "Base palette (custom colors below are kept)",
		Options = presetNames,
		Callback = function(name)
			for _, preset in Theme.Presets do
				if preset.Name == name then
					theme:SetSeedColor(Color3.fromHex(preset.Seed))
				end
			end
		end,
	})

	-- One picker per color role. `editing` stops the picker being dragged
	-- from being reset by the Changed event its own edit causes.
	local pickers = {}
	local editing = nil
	for _, entry in Theme.EditableRoles do
		local role = entry.Role
		pickers[role] = section:AddColorPicker({
			Title = entry.Name,
			Description = role,
			Default = theme.Colors[role],
			Transparency = theme:GetTransparency(role) or 0,
			Callback = function(color, transparency)
				editing = role
				theme:SetOverride(role, color, transparency)
				editing = nil
			end,
		})
	end

	local function refresh()
		for role, picker in pickers do
			local color = theme.Colors[role]
			local transparency = theme:GetTransparency(role) or 0
			if role ~= editing and (picker.Value ~= color or picker.Transparency ~= transparency) then
				picker:Set({ Color = color, Transparency = transparency }, true)
			end
			picker:SetDescription(if theme:IsOverridden(role) then `{role} · custom` else role)
		end
	end
	refresh()
	self._maid:GiveTask(theme.Changed:Connect(refresh))

	section:AddButton({
		Title = "Reset custom colors",
		Description = "Back to the colors generated from the accent color",
		Icon = "refresh",
		Callback = function()
			theme:ClearOverrides()
			self:Notify({ Title = "Custom colors cleared", Icon = "refresh", Duration = 3 })
		end,
	})
	section:AddButton({
		Title = "Copy theme",
		Description = "Copies the theme as JSON to share or back up",
		Icon = "content_copy",
		Callback = function()
			local json = HttpService:JSONEncode(theme:Export())
			if Env.SetClipboard(json) then
				self:Notify({ Title = "Theme copied", Icon = "content_copy", Duration = 3 })
			else
				self:Notify({ Title = "Clipboard unavailable", Content = json, Icon = "error", Duration = 10 })
			end
		end,
	})
	section:AddInput({
		Title = "Import theme",
		Placeholder = "Paste theme JSON",
		ClearOnSubmit = true,
		Callback = function(text)
			if text == "" then
				return
			end
			local ok, data = pcall(HttpService.JSONDecode, HttpService, text)
			local imported = ok and pcall(theme.Import, theme, data)
			self:Notify({
				Title = if imported then "Theme imported" else "Invalid theme JSON",
				Icon = if imported then "palette" else "error",
				Duration = 3,
			})
		end,
	})

	-- Overrides go into configs as one flag (saving every picker would pin
	-- generated colors too and stop them following the accent color).
	-- Value: { Colors = { [role] = Color3 }, Transparency = { [role] = number } }
	local function current()
		return { Colors = theme:GetOverrides(), Transparency = theme:GetTransparencies() }
	end
	local overridesFlag = { Type = "ThemeOverrides", Flag = "MD3_ThemeOverrides", Value = current() }
	function overridesFlag:Set(value)
		if type(value) ~= "table" then
			theme:ClearOverrides()
		elseif value.Colors or value.Transparency then
			theme:SetOverrides(value.Colors or {}, value.Transparency or {})
		else
			theme:SetOverrides(value, {}) -- configs saved before transparency existed
		end
	end
	function overridesFlag:Get()
		return current()
	end
	function overridesFlag:Destroy() end
	self.Flags.MD3_ThemeOverrides = overridesFlag
	self._maid:GiveTask(theme.Changed:Connect(function()
		overridesFlag.Value = current()
	end))

	return section
end

--== Teardown ==--

function Window:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self.OnUnload:Fire()
	for _, tab in self.Tabs do
		pcall(tab.Destroy, tab)
	end
	self._maid:Destroy()
	self._themer:Destroy()
	Elevation.Remove(self.Instance)
	self.Gui:Destroy()

	local registry = Env.Registry()
	if registry.Windows and registry.Windows[self._registryKey] == self then
		registry.Windows[self._registryKey] = nil
	end
end
Window.Unload = Window.Destroy

return Window
