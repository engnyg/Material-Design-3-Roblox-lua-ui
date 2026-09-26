--[[
	Executor-style window built from MD3 components.

	local Window = MD3:CreateWindow({
		Title = "My Hub",
		Subtitle = "v1.0",
		Icon = "widgets",                  -- Material icon name, or an image (URL / rbxassetid)
		ThemeColor = Color3.fromHex("#6750A4"), -- theme (seed) color the palette is generated from
		Preset = nil,                      -- built-in theme preset, e.g. "NeverLose" (Theme.Presets)
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
		Background = nil,                  -- background image (PNG / JPG) or WebM video: URL / rbxassetid / asset id
		BackgroundKind = nil,              -- "Video" for a Roblox video asset id (a .webm is detected by itself)
		BackgroundTransparency = 0.4,      -- how much of the window color shows through the image
		BackgroundBlur = 0,                -- blur a background image, 0-24 px
		Silent = false,                    -- true: no loading screen, start hidden, no automatic notifications
		KeybindNotify = true,              -- toast when a keybind (AddKeybind) is used; not for the UI toggle key
	})

	local Main = Window:AddTab({ Title = "Main", Icon = "home" })
	Main:AddToggle({ Title = "Auto farm", Flag = "AutoFarm", Callback = function(on) end })

	Window:Notify({ Title = "Loaded", Content = "Press RightShift to hide", Icon = "check_circle" })

	-- HUD (stays up while the window is hidden)
	Window:AddWatermark({ FPS = true, Ping = true, Clock = true })
	Window:AddKeybindList()
	Window:AddIndicator({ Text = "AUTO", Icon = "bolt" })

	-- Loading screen: on by default; LoadingScreen = false turns it off,
	-- or { Title, Subtitle, Icon, Duration } customizes it.
	if not Window.IsLoaded then Window.Loaded:Wait() end -- if you need the window on screen first
]]
local ContentProvider = game:GetService("ContentProvider")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
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
local Assets = require(Root.Executor.Assets)
local IconImages = require(Root.Executor.IconImages)
local Themer = require(script.Parent.Themer)
local Config = require(script.Parent.Config)
local Notifier = require(script.Parent.Notifier)
local Tab = require(script.Parent.Tab)
local Base = require(script.Parent.Elements.Base)
local makeDraggable = require(script.Parent.Draggable)
local HUD = require(script.Parent.HUD)
local LoadingScreen = require(script.Parent.LoadingScreen)

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

-- Where the copies of a blurred background image go: the image itself, then
-- two rings of 6 (half and full radius, the outer ring turned 30 degrees).
-- Averaging the copies gives a soft blur; Roblox has no blur for UI.
local MAX_BACKGROUND_BLUR = 24
local function blurOffsets(radius: number): { Vector2 }
	local offsets = { Vector2.new(0, 0) }
	if radius <= 0 then
		return offsets
	end
	for ring, distance in { radius * 0.5, radius } do
		for i = 0, 5 do
			local angle = (i / 6 + (ring - 1) / 12) * math.pi * 2
			table.insert(offsets, Vector2.new(math.cos(angle) * distance, math.sin(angle) * distance))
		end
	end
	return offsets
end

-- True for a .webm URL / file, which SetBackground plays as a video.
local function isVideoSource(source): boolean
	if type(source) ~= "string" then
		return false
	end
	local path = source:gsub("[?#].*$", "")
	return path:lower():match("%.webm$") ~= nil
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
	-- Fires once the loading screen is done and the window is shown (right
	-- away when there is no loading screen: check IsLoaded before waiting).
	self.Loaded = Signal.new()
	self.IsLoaded = false
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
	-- The loading screen waits for this.
	self._iconsReady = true
	if props.Icons ~= false and props.IconFont ~= false and (props.IconStyle ~= nil or not Icons.GetSheet()) then
		self._iconsReady = false
		task.spawn(function()
			local ok, err = IconImages.Load(props.IconStyle)
			self._iconsReady = true
			if not ok and Env.CanUseCustomAssets then
				warn(`[MD3] could not load the icon images: {err}`)
			end
		end)
	end

	self.Theme = props.Theme or Theme.new(props.ThemeColor or props.Seed or props.Accent, props.Mode or "Dark")
	-- A preset first; explicit ThemeColor / Mode / TextColor / IconColor win over it.
	if props.Preset and not props.Theme then
		if not self.Theme:ApplyPreset(props.Preset) then
			warn(`[MD3] unknown theme preset "{props.Preset}"`)
		end
		local seed = props.ThemeColor or props.Seed or props.Accent
		if seed then
			self.Theme:SetSeedColor(seed)
		end
		if props.Mode then
			self.Theme:SetMode(props.Mode)
		end
	end
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

	--== Backdrop (dark dimming overlay) ==--
	local backdrop = Create("Frame") {
		Name = "Backdrop",
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		ZIndex = 0,
		Active = false,
		Visible = false,
		Parent = gui,
	}
	self._backdrop = backdrop
	self._backdropEnabled = props.Backdrop ~= false
	self._backdropTransparency = props.BackdropTransparency or 0.55

	--== Snowfall Particle Effect ==--
	local snowContainer = Create("Frame") {
		Name = "SnowContainer",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		ClipsDescendants = true,
		ZIndex = 0,
		Active = false,
		Visible = false,
		Parent = gui,
	}
	self._snowContainer = snowContainer
	self._snowEnabled = props.Snowfall == true
	self._snowSettings = {
		SpeedMultiplier = props.SnowSpeed or 1.0,
		BaseSize = props.SnowBaseSize or 5,
		Count = props.SnowCount or 45,
	}
	self._snowflakes = {}

	local function getScreenBounds()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
		return math.max(vp.X, 800), math.max(vp.Y, 600)
	end

	local function createFlake(i)
		local sw, sh = getScreenBounds()
		local flake = Create("Frame") {
			Name = "Flake_" .. i,
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.fromRGB(240, 245, 255),
			Parent = snowContainer,
			[1] = Create("UICorner") { CornerRadius = UDim.new(1, 0) },
		}
		local sizeRatio = math.random(70, 140) / 100
		local curSize = math.clamp(math.round(self._snowSettings.BaseSize * sizeRatio), 2, 30)
		flake.Size = UDim2.fromOffset(curSize, curSize)
		flake.BackgroundTransparency = math.random(25, 70) / 100
		local posX = math.random(0, sw)
		local posY = math.random(0, sh)
		flake.Position = UDim2.fromOffset(posX, posY)
		return {
			inst = flake,
			x = posX,
			y = posY,
			sizeRatio = sizeRatio,
			baseSpeed = math.random(40, 100),
			swayAmp = math.random(15, 35),
			swayFreq = math.random(8, 20) / 10,
			phase = math.random() * math.pi * 2,
		}
	end
	self._createFlake = createFlake

	for i = 1, self._snowSettings.Count do
		table.insert(self._snowflakes, createFlake(i))
	end

	local snowElapsed = 0
	self._maid:GiveTask(RunService.RenderStepped:Connect(function(dt)
		if not (self.Visible and not self.Minimized and self._snowEnabled) then
			return
		end
		snowElapsed += dt
		local sw, sh = getScreenBounds()
		for _, f in ipairs(self._snowflakes) do
			f.y += f.baseSpeed * self._snowSettings.SpeedMultiplier * dt
			if f.y > sh + 10 then
				f.y = -10
				f.x = math.random(0, sw)
			end
			local currentX = (f.x + math.sin(snowElapsed * f.swayFreq + f.phase) * f.swayAmp) % sw
			f.inst.Position = UDim2.fromOffset(currentX, f.y)
		end
	end))

	--== Custom Cursor ==--
	local cursorSettings = {
		Enabled = props.CustomCursor == true,
		Scale = props.CursorScale or 100,
	}
	self._cursorSettings = cursorSettings

	local cursorGui = Create("ScreenGui") {
		Name = "CustomCursorGui",
		ResetOnSpawn = false,
		DisplayOrder = 999999,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = gui.Parent or Env.GetGuiParent(),
	}
	Env.ProtectGui(cursorGui)
	self._cursorGui = cursorGui
	self._maid:GiveTask(cursorGui)

	local cursorContainer = Create("Frame") {
		Name = "CursorContainer",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 0),
		Active = false,
		Visible = false,
		Parent = cursorGui,
	}
	self._cursorContainer = cursorContainer

	local cursorScale = Create("UIScale") {
		Name = "CursorScale",
		Scale = cursorSettings.Scale / 100,
		Parent = cursorContainer,
	}
	self._cursorScale = cursorScale

	local cursorPointer = Create("ImageLabel") {
		Name = "CursorPointer",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(64, 64),
		Position = UDim2.fromOffset(-31, -32),
		Image = "rbxasset://textures/Cursors/KeyboardMouse/ArrowFarCursor.png",
		ImageColor3 = self.Theme.Colors.Primary or Color3.fromRGB(220, 205, 255),
		Active = false,
		ZIndex = 1000000,
		Parent = cursorContainer,
	}
	themer:Bind(cursorPointer, { ImageColor3 = "Primary" })
	self._cursorPointer = cursorPointer

	self._maid:GiveTask(RunService.RenderStepped:Connect(function()
		if self.Visible and not self.Minimized then
			if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end
			if not (self._cursorSettings and self._cursorSettings.Enabled) then
				if not UserInputService.MouseIconEnabled then
					UserInputService.MouseIconEnabled = true
				end
			end
		end
		if cursorContainer and cursorContainer.Visible then
			local mousePos = UserInputService:GetMouseLocation()
			cursorContainer.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
		end
	end))

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

	-- Custom background (SetBackground): an image, or a looping muted WebM
	-- video, behind everything in the window and rounded like it. Its
	-- transparency lets the window color through.
	-- The image lives in a CanvasGroup: it clips the blur copies to the
	-- window's rounded shape and fades them together (GroupTransparency).
	local backgroundGroup = Create("CanvasGroup") {
		Name = "Background",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Visible = false,
		Parent = main,
	}
	Shape.Corner(Shape.Large, backgroundGroup)
	local background = Create("ImageLabel") {
		Name = "Image",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 1,
		Visible = false,
		Parent = backgroundGroup,
	}
	local video = Create("VideoFrame") {
		Name = "BackgroundVideo",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Looped = true,
		Volume = 0,
		Visible = false,
		Parent = main,
	}
	Shape.Corner(Shape.Large, video)
	-- A VideoFrame has no transparency of its own: a window-colored veil on
	-- top does what ImageTransparency does for the image.
	local veil = Create("Frame") {
		Name = "Veil",
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = video,
	}
	Shape.Corner(Shape.Large, veil)
	themer:Bind(veil, {
		BackgroundColor3 = function(colors)
			return colors.Surface
		end,
	})
	-- Don't decode video nobody can see.
	self._maid:GiveTask(main:GetPropertyChangedSignal("Visible"):Connect(function()
		video.Playing = main.Visible and video.Visible
	end))
	self._background = background
	self._backgroundGroup = backgroundGroup
	self._backgroundLayers = { background } -- [1] is the image itself, then blur copies
	self._backgroundBlur = 0
	self._backgroundVideo = video
	self._backgroundVeil = veil
	self._backgroundSource = nil
	self._backgroundKind = nil
	self._backgroundTransparency = math.clamp(props.BackgroundTransparency or 0.4, 0, 1)
	backgroundGroup.GroupTransparency = self._backgroundTransparency
	veil.BackgroundTransparency = 1 - self._backgroundTransparency
	if props.BackgroundBlur then
		self:SetBackgroundBlur(props.BackgroundBlur)
	end

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
		Visible = props.Actions ~= false,
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

	if props.MinimizeButton ~= false then
		barButton("minimize", 1, function()
			self:Minimize()
		end)
	end
	if props.CloseButton ~= false then
		barButton("close", 2, function()
			self:_confirmClose()
		end)
	end

	makeDraggable(self._maid, topBar, main)

	--== TopBar Search Box & Settings Search Dropdown ==--
	self._searchableItems = {}
	if props.Search ~= false then
		local searchBox = Create("Frame") {
			Name = "TopLeftSearchBox",
			Size = UDim2.new(0, 210, 0, 32),
			Position = UDim2.new(0, 140, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = self.Theme.Colors.SurfaceContainerHigh or Color3.fromRGB(30, 28, 38),
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = topBar,
			[1] = Create("UICorner") { CornerRadius = UDim.new(0, 8) },
			[2] = Create("UIStroke") {
				Color = self.Theme.Colors.OutlineVariant or Color3.fromRGB(65, 60, 80),
				Thickness = 1,
				Transparency = 0.4,
			},
		}
		themer:Bind(searchBox, { BackgroundColor3 = "SurfaceContainerHigh" })

		local searchIcon = Create("ImageLabel") {
			Name = "SearchIcon",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(16, 16),
			Position = UDim2.new(0, 8, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Image = "rbxasset://textures/ui/SearchIcon.png",
			ImageColor3 = self.Theme.Colors.OnSurfaceVariant or Color3.fromRGB(160, 155, 175),
			ZIndex = 6,
			Parent = searchBox,
		}
		themer:Bind(searchIcon, { ImageColor3 = "OnSurfaceVariant" })

		local searchInput = Create("TextBox") {
			Name = "SearchInput",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -56, 1, 0),
			Position = UDim2.new(0, 30, 0, 0),
			PlaceholderText = props.SearchPlaceholder or "Search settings...",
			PlaceholderColor3 = Color3.fromRGB(140, 135, 155),
			Text = "",
			TextColor3 = self.Theme.Colors.OnSurface or Color3.fromRGB(240, 240, 255),
			TextSize = 13,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false,
			ZIndex = 6,
			Parent = searchBox,
		}
		themer:Bind(searchInput, { TextColor3 = "OnSurface" })

		local clearBtn = Create("TextButton") {
			Name = "ClearBtn",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(20, 20),
			Position = UDim2.new(1, -6, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Text = "x",
			TextColor3 = Color3.fromRGB(150, 145, 165),
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			Visible = false,
			ZIndex = 6,
			Parent = searchBox,
		}

		local searchDropdown = Create("Frame") {
			Name = "SearchDropdown",
			Size = UDim2.new(0, 260, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.new(0, 140, 0, TOP_BAR_HEIGHT - 4),
			BackgroundColor3 = self.Theme.Colors.SurfaceContainerHigh or Color3.fromRGB(24, 22, 30),
			BorderSizePixel = 0,
			ZIndex = 60,
			Visible = false,
			Parent = main,
			[1] = Create("UICorner") { CornerRadius = UDim.new(0, 10) },
			[2] = Create("UIStroke") {
				Color = self.Theme.Colors.OutlineVariant or Color3.fromRGB(70, 65, 85),
				Thickness = 1,
				Transparency = 0.3,
			},
			[3] = Create("UIListLayout") {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			},
			[4] = Create("UIPadding") {
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
			},
		}
		themer:Bind(searchDropdown, { BackgroundColor3 = "SurfaceContainerHigh" })

		clearBtn.Activated:Connect(function()
			searchInput.Text = ""
			clearBtn.Visible = false
			searchDropdown.Visible = false
		end)

		local function performJump(item)
			searchDropdown.Visible = false
			if item.tab then
				self:SelectTab(item.tab)
			end
			task.wait(0.08)
			if item.subTab and item.tab then
				if item.tab._subTabs and item.tab._subTabs[item.subTab] and item.tab._subTabs[item.subTab].Select then
					item.tab._subTabs[item.subTab].Select()
				elseif item.tab.Instance then
					local subBtn = item.tab.Instance:FindFirstChild("SubBtn_" .. item.subTab, true)
					if subBtn and typeof(getconnections) == "function" then
						for _, conn in ipairs(getconnections(subBtn.Activated)) do
							conn:Fire()
						end
					end
				end
			end
			task.wait(0.08)
			local targetInst = item.target
			if targetInst and targetInst:IsDescendantOf(game) then
				local page = item.tab and item.tab.Instance
				if page and page:IsA("ScrollingFrame") then
					local relY = targetInst.AbsolutePosition.Y - page.AbsolutePosition.Y + page.CanvasPosition.Y
					page.CanvasPosition = Vector2.new(0, math.max(0, relY - 40))
				end
				local highlight = Instance.new("UIStroke")
				highlight.Name = "SearchHighlight"
				highlight.Color = self.Theme.Colors.Primary or Color3.fromRGB(180, 160, 255)
				highlight.Thickness = 2
				highlight.Transparency = 0
				highlight.Parent = targetInst
				TweenService:Create(highlight, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = 1,
					Thickness = 4,
				}):Play()
				task.delay(1.3, function()
					pcall(function() highlight:Destroy() end)
				end)
			end
		end

		searchInput:GetPropertyChangedSignal("Text"):Connect(function()
			local query = searchInput.Text:lower():match("^%s*(.-)%s*$")
			clearBtn.Visible = (searchInput.Text ~= "")
			if not query or query == "" then
				searchDropdown.Visible = false
				return
			end

			local matches = {}
			for _, item in ipairs(self._searchableItems) do
				if (item.name and string.find(item.name:lower(), query, 1, true)) or (item.path and string.find(item.path:lower(), query, 1, true)) then
					table.insert(matches, item)
					if #matches >= 8 then break end
				end
			end

			for _, child in ipairs(searchDropdown:GetChildren()) do
				if child:IsA("TextButton") or child:IsA("Frame") then
					child:Destroy()
				end
			end

			if #matches == 0 then
				local empty = Create("TextLabel") {
					Name = "EmptyLabel",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 28),
					Text = "No settings found",
					TextColor3 = Color3.fromRGB(140, 135, 155),
					Font = Enum.Font.Gotham,
					TextSize = 12,
					ZIndex = 61,
					Parent = searchDropdown,
				}
				searchDropdown.Visible = true
				return
			end

			for i, match in ipairs(matches) do
				local resBtn = Create("TextButton") {
					Name = "Result_" .. i,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 36),
					LayoutOrder = i,
					Text = "",
					AutoButtonColor = false,
					ZIndex = 61,
					Parent = searchDropdown,
					[1] = Create("UICorner") { CornerRadius = UDim.new(0, 6) },
				}
				local titleLbl = Create("TextLabel") {
					Name = "Title",
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 8, 0, 3),
					Size = UDim2.new(1, -16, 0, 16),
					Text = match.name or "Setting",
					Font = Enum.Font.GothamBold,
					TextSize = 13,
					TextColor3 = Color3.fromRGB(230, 230, 245),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					ZIndex = 62,
					Parent = resBtn,
				}
				local pathLbl = Create("TextLabel") {
					Name = "Path",
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 8, 0, 19),
					Size = UDim2.new(1, -16, 0, 14),
					Text = match.path or "",
					Font = Enum.Font.Gotham,
					TextSize = 10,
					TextColor3 = Color3.fromRGB(150, 145, 170),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					ZIndex = 62,
					Parent = resBtn,
				}

				resBtn.MouseEnter:Connect(function()
					resBtn.BackgroundTransparency = 0.8
					resBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				end)
				resBtn.MouseLeave:Connect(function()
					resBtn.BackgroundTransparency = 1
				end)
				resBtn.Activated:Connect(function()
					performJump(match)
				end)
			end

			searchDropdown.Visible = true
		end)
	end

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
		Position = UDim2.new(0, 16, 0, 4),
		Size = UDim2.new(1, -32, 0, 42),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ZIndex = 3,
		Parent = body,
		[1] = Create("UIPadding") {
			PaddingLeft = UDim.new(0, 0),
			PaddingRight = UDim.new(0, 0),
			PaddingTop = UDim.new(0, 0),
			PaddingBottom = UDim.new(0, 0),
		},
		[2] = Create("UIListLayout") {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		},
	}
	self._navList = navList

	-- Floating sliding indicator pill inside body (behind navList buttons)
	local navPill = Create("Frame") {
		Name = "NavSlideIndicator",
		BackgroundColor3 = self.Theme.Colors.SecondaryContainer or Color3.fromRGB(74, 68, 88),
		BorderSizePixel = 0,
		ZIndex = 1,
		Active = false,
		Visible = false,
		Parent = body,
	}
	Shape.Corner(Shape.Full, navPill)
	local pillStroke = Create("UIStroke") {
		Thickness = 1.2,
		Color = self.Theme.Colors.Primary or Color3.fromRGB(208, 188, 255),
		Transparency = 0.5,
		Parent = navPill,
	}
	themer:Bind(navPill, { BackgroundColor3 = "SecondaryContainer" })
	themer:Bind(pillStroke, { Color = "Primary" })
	self._navPill = navPill

	local pages = Create("Frame") {
		Name = "Pages",
		BorderSizePixel = 0,
		Position = UDim2.new(0, 16, 0, 50),
		Size = UDim2.new(1, -32, 1, -60),
		ClipsDescendants = true,
		Parent = body,
	}
	Shape.Corner(Shape.Large, pages)
	themer:Bind(pages, { BackgroundColor3 = "SurfaceContainerLow" })
	self._pages = pages

	self._maid:GiveTask(navList:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if self._currentActiveBtn and self._currentActiveBtn:IsDescendantOf(game) and self._navPill and self._body then
			local relX = self._currentActiveBtn.AbsolutePosition.X - self._body.AbsolutePosition.X
			local relY = self._currentActiveBtn.AbsolutePosition.Y - self._body.AbsolutePosition.Y
			self._navPill.Position = UDim2.fromOffset(relX, relY)
			self._navPill.Size = UDim2.fromOffset(self._currentActiveBtn.AbsoluteSize.X, self._currentActiveBtn.AbsoluteSize.Y)
		end
	end))

	self._maid:GiveTask(body:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if self._currentActiveBtn and self._currentActiveBtn:IsDescendantOf(game) and self._navPill and self._body then
			local relX = self._currentActiveBtn.AbsolutePosition.X - self._body.AbsolutePosition.X
			local relY = self._currentActiveBtn.AbsolutePosition.Y - self._body.AbsolutePosition.Y
			self._navPill.Position = UDim2.fromOffset(relX, relY)
			self._navPill.Size = UDim2.fromOffset(self._currentActiveBtn.AbsoluteSize.X, self._currentActiveBtn.AbsoluteSize.Y)
		end
	end))

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

	--== Silent start ==--
	-- Nothing pops up: no loading screen, the window starts hidden (toggle
	-- key / mobile button opens it) and autoload doesn't notify.
	self.Silent = props.Silent == true
	-- Toasts when the player's own keybinds (AddKeybind) are used; the UI
	-- toggle key never notifies. Off in Silent mode.
	self._keybindNotify = props.KeybindNotify ~= false
	if self.Silent then
		self.Visible = false
		main.Visible = false
	end

	--== Loading screen ==--
	-- On unless the script passes LoadingScreen = false (or Silent); the
	-- player can also turn it off from the settings tab (ConfigFolder/loading.txt).
	self._loadingAllowed = props.LoadingScreen ~= false and not self.Silent
	if self._loadingAllowed and self:GetLoadingScreenEnabled() then
		self._loading = true
		main.Visible = false
		self._loadingScreen = LoadingScreen.Run(self, props.LoadingScreen, function()
			self._loading = false
			self._loadingScreen = nil
			if self._destroyed then
				return
			end
			self.IsLoaded = true
			if self.Visible then
				self:SetVisible(true)
			end
			self.Loaded:Fire()
		end)
	else
		self.IsLoaded = true
	end

	if props.Background then
		-- Downloading can take a moment; don't hold up CreateWindow.
		task.spawn(function()
			local ok, err = self:SetBackground(props.Background, nil, props.BackgroundKind)
			if not ok and not self._destroyed then
				warn(`[MD3] background: {err}`)
				if not self.Silent then
					self:Notify({ Title = "Background unavailable", Content = err or "", Icon = "error" })
				end
			end
		end)
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

function Window:_slideToTab(tab, instant)
	if not (tab and tab._button and self._navPill and self._body) then
		return
	end
	self._currentActiveBtn = tab._button
	local btn = tab._button
	local relX = btn.AbsolutePosition.X - self._body.AbsolutePosition.X
	local relY = btn.AbsolutePosition.Y - self._body.AbsolutePosition.Y
	local targetPos = UDim2.fromOffset(relX, relY)
	local targetSize = UDim2.fromOffset(btn.AbsoluteSize.X, btn.AbsoluteSize.Y)

	if self._pillTween then
		self._pillTween:Cancel()
		self._pillTween = nil
	end

	self._navPill.Visible = true
	if instant then
		self._navPill.Position = targetPos
		self._navPill.Size = targetSize
	else
		self._pillTween = TweenService:Create(self._navPill, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = targetPos,
			Size = targetSize,
		})
		self._pillTween:Play()
	end
end

function Window:AddTab(props)
	local tab = Tab.new(self, props)
	table.insert(self.Tabs, tab)
	if not self.SelectedTab then
		self:SelectTab(tab)
		task.defer(function()
			self:_slideToTab(tab, true)
		end)
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
	self:_slideToTab(tab, false)
end

--== Visibility ==--

function Window:SetVisible(visible: boolean)
	self.Visible = visible
	if self._loading then
		return -- applied when the loading screen finishes
	end
	local main = self.Instance
	if visible then
		main.Visible = true
		local target = self._uiScale.Scale
		self._uiScale.Scale = target * 0.94
		TweenService:Create(self._uiScale, Motion.Emphasized(Motion.Duration.Medium2), { Scale = target }):Play()

		if self._backdropEnabled and self._backdrop then
			self._backdrop.Visible = true
			TweenService:Create(self._backdrop, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = self._backdropTransparency,
			}):Play()
		end
		if self._snowEnabled and self._snowContainer then
			self._snowContainer.Visible = true
		end
		self:_updateCursorState(true)
	else
		main.Visible = false
		if self._backdrop then
			local tw = TweenService:Create(self._backdrop, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1,
			})
			tw:Play()
			tw.Completed:Connect(function()
				if not self.Visible and self._backdrop then
					self._backdrop.Visible = false
				end
			end)
		end
		if self._snowContainer then
			self._snowContainer.Visible = false
		end
		self:_updateCursorState(false)
	end
end

function Window:_registerSearchable(item)
	table.insert(self._searchableItems, item)
end

function Window:AddSearchableSetting(item)
	self:_registerSearchable(item)
end

function Window:SetBackdrop(enabled: boolean, transparency: number?)
	self._backdropEnabled = enabled
	if transparency then
		self._backdropTransparency = transparency
	end
	if self._backdrop then
		if enabled and self.Visible and not self.Minimized then
			self._backdrop.Visible = true
			TweenService:Create(self._backdrop, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = self._backdropTransparency,
			}):Play()
		else
			self._backdrop.Visible = false
		end
	end
end

function Window:SetSnowfall(enabled: boolean, count: number?, speed: number?, size: number?)
	self._snowEnabled = enabled
	if count and self._snowSettings then
		self._snowSettings.Count = count
		while #self._snowflakes < count do
			table.insert(self._snowflakes, self._createFlake(#self._snowflakes + 1))
		end
		while #self._snowflakes > count do
			local f = table.remove(self._snowflakes)
			if f and f.inst then f.inst:Destroy() end
		end
	end
	if speed and self._snowSettings then self._snowSettings.SpeedMultiplier = speed end
	if size and self._snowSettings then
		self._snowSettings.BaseSize = size
		for _, f in ipairs(self._snowflakes) do
			local curSize = math.clamp(math.round(size * (f.sizeRatio or 1)), 2, 30)
			f.inst.Size = UDim2.fromOffset(curSize, curSize)
		end
	end
	if self._snowContainer then
		self._snowContainer.Visible = enabled and self.Visible and not self.Minimized
	end
end

function Window:SetCustomCursor(enabled: boolean, scale: number?)
	if self._cursorSettings then
		self._cursorSettings.Enabled = enabled
		if scale then
			self._cursorSettings.Scale = scale
			if self._cursorScale then
				self._cursorScale.Scale = scale / 100
			end
		end
	end
	self:_updateCursorState(self.Visible and not self.Minimized)
end

function Window:_updateCursorState(open: boolean)
	if open then
		pcall(function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end)
		if self._cursorSettings and self._cursorSettings.Enabled then
			UserInputService.MouseIconEnabled = false
			if self._cursorContainer then self._cursorContainer.Visible = true end
		else
			if self._cursorContainer then self._cursorContainer.Visible = false end
			UserInputService.MouseIconEnabled = true
		end
	else
		if self._cursorContainer then self._cursorContainer.Visible = false end
		UserInputService.MouseIconEnabled = true
	end
end

function Window:SetScale(scale: number)
	if self._uiScale then
		self._uiScale.Scale = scale
	end
end

function Window:GetScale(): number
	return self._uiScale and self._uiScale.Scale or 1
end

function Window:SetTransparency(transparency: number)
	if self.Instance then
		self.Instance.BackgroundTransparency = transparency
	end
	if self._pages then
		self._pages.BackgroundTransparency = math.clamp(transparency + 0.1, 0, 1)
	end
end

function Window:GetTransparency(): number
	return self.Instance and self.Instance.BackgroundTransparency or 0
end

function Window:Toggle()
	self:SetVisible(not self.Visible)
end

-- Whether keybind toasts are on for this window (off in Silent mode).
function Window:GetKeybindNotify(): boolean
	return self._keybindNotify and not self.Silent
end

function Window:SetKeybindNotify(enabled: boolean)
	self._keybindNotify = enabled
end

-- Ends the loading screen now (e.g. once your own setup is done).
function Window:SkipLoading()
	if self._loadingScreen then
		self._loadingScreen.Finish()
	end
end

-- The player's loading-screen preference, used from the next run on
-- (true unless turned off; always false when the script disabled it).
function Window:GetLoadingScreenEnabled(): boolean
	if not self._loadingAllowed then
		return false
	end
	return Env.ReadFile(`{self._configFolder}/loading.txt`) ~= "off"
end

function Window:SetLoadingScreenEnabled(enabled: boolean): boolean
	if not Env.CanUseFiles then
		return false
	end
	Env.MakeFolder(self._configFolder)
	return Env.WriteFile(`{self._configFolder}/loading.txt`, if enabled then "on" else "off")
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

--== Custom background ==--

-- Background behind the whole window: an image (PNG / JPG) or a WebM video
-- (looping, muted), as a URL, rbxassetid://, asset id or workspace file;
-- nil or "" removes it. `transparency` (0-1, optional) also sets how much of
-- the window color shows through. `kind` ("Image" | "Video") is only needed
-- for a Roblox video asset id; otherwise a .webm is played as a video.
-- If it can't be loaded (e.g. a GIF, which Roblox can't show) the current
-- background is kept and this returns false plus the reason.
function Window:SetBackground(source: string?, transparency: number?, kind: string?): (boolean, string?)
	if transparency ~= nil then
		self:SetBackgroundTransparency(transparency)
	end
	local image, video = self._background, self._backgroundVideo
	if source == nil or source == "" then
		self._backgroundSource, self._backgroundKind = nil, nil
		image.Image = ""
		image.Visible = false
		self._backgroundGroup.Visible = false
		video.Playing = false
		video.Video = ""
		video.Visible = false
	else
		local isVideo = if kind then kind == "Video" else isVideoSource(source)
		local content, problem = Assets.ResolveWithReason(source, if isVideo then "video" else "image")
		if content == "" then
			return false, problem or `could not load {source}`
		end
		self._backgroundSource = source
		self._backgroundKind = if isVideo then "Video" else "Image"
		image.Image = if isVideo then "" else content
		image.Visible = not isVideo
		self._backgroundGroup.Visible = not isVideo
		video.Video = if isVideo then content else ""
		video.Visible = isVideo
		video.Playing = isVideo and self.Instance.Visible
		if isVideo then
			self:_checkBackgroundVideo(source)
		end
	end
	self:_layoutBackgroundBlur()
	self:_syncBackgroundControls()
	return true
end

-- A video can download fine and still be refused by Roblox (some executors'
-- getcustomasset can't serve local videos, e.g. on mobile). Ask
-- ContentProvider in the background; if it fails, drop the video and say why.
function Window:_checkBackgroundVideo(source: string)
	local video = self._backgroundVideo
	task.spawn(function()
		local failed = false
		pcall(function()
			ContentProvider:PreloadAsync({ video }, function(_, status)
				if status == Enum.AssetFetchStatus.Failure then
					failed = true
				end
			end)
		end)
		if not failed or self._destroyed or self._backgroundSource ~= source then
			return
		end
		self:SetBackground(nil)
		local reason = "Roblox couldn't play this WebM video here (this executor may not support local videos). Use a PNG / JPG image background instead."
		warn(`[MD3] background: {reason}`)
		if not self.Silent then
			self:Notify({ Title = "Background unavailable", Content = reason, Icon = "error" })
		end
	end)
end

function Window:SetBackgroundTransparency(transparency: number)
	self._backgroundTransparency = math.clamp(transparency, 0, 1)
	self._backgroundGroup.GroupTransparency = self._backgroundTransparency
	self._backgroundVeil.BackgroundTransparency = 1 - self._backgroundTransparency
	self:_syncBackgroundControls()
end

-- Blurs a background image by `pixels` (0 = sharp, up to 24). Roblox has no
-- blur for UI, so this draws 13 offset copies of the image and averages
-- them; 0 keeps a single image. Video backgrounds aren't blurred (each copy
-- would decode the video again).
function Window:SetBackgroundBlur(pixels: number)
	self._backgroundBlur = math.clamp(pixels, 0, MAX_BACKGROUND_BLUR)
	self:_layoutBackgroundBlur()
	self:_syncBackgroundControls()
end

function Window:GetBackgroundBlur(): number
	return self._backgroundBlur
end

-- Makes the image copies match the blur amount and the current image.
function Window:_layoutBackgroundBlur()
	local layers = self._backgroundLayers
	local image = self._background
	local offsets = blurOffsets(if image.Image ~= "" then self._backgroundBlur else 0)
	for i = #layers, #offsets + 1, -1 do
		layers[i]:Destroy()
		layers[i] = nil
	end
	for i = #layers + 1, #offsets do
		layers[i] = Create("ImageLabel") {
			Name = `Blur{i}`,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			ScaleType = Enum.ScaleType.Crop,
			Parent = self._backgroundGroup,
		}
	end
	-- Copies are drawn a little bigger than the window so offsetting them
	-- never uncovers its edges; the group clips them to the window shape.
	local pad = math.ceil(if #offsets > 1 then self._backgroundBlur else 0)
	for i, layer in layers do
		local offset = offsets[i]
		layer.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
		layer.Size = UDim2.new(1, pad * 2, 1, pad * 2)
		layer.ZIndex = i
		-- Layer i drawn over the ones below it at opacity 1/i gives every
		-- copy the same weight: an even average.
		layer.ImageTransparency = 1 - 1 / i
		if i > 1 then
			layer.Image = image.Image
		end
	end
end

-- The current background (as given to SetBackground, nil when none), its
-- transparency, and "Image" / "Video".
function Window:GetBackground(): (string?, number, string?)
	return self._backgroundSource, self._backgroundTransparency, self._backgroundKind
end

-- Keeps the settings tab's Background controls showing the real state.
function Window:_syncBackgroundControls()
	local controls = self._backgroundControls
	if not controls then
		return
	end
	local source = self._backgroundSource or ""
	if controls.Input.Value ~= source then
		controls.Input:Set(source, true)
	end
	local percent = math.round(self._backgroundTransparency * 100)
	if controls.Slider.Value ~= percent then
		controls.Slider:Set(percent, true)
	end
	if controls.Blur.Value ~= self._backgroundBlur then
		controls.Blur:Set(self._backgroundBlur, true)
	end
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
		if not self.Silent then
			self:Notify({ Title = "Config loaded", Content = `Auto-loaded "{name}"`, Icon = "folder" })
		end
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

	-- Custom background (saved in configs as MD3_Background / MD3_BackgroundTransparency).
	local backgroundSection = tab:AddSection("Background")
	local backgroundInput
	backgroundInput = backgroundSection:AddInput({
		Title = "Background image",
		Description = "PNG / JPG image or WebM video: URL, rbxassetid:// or asset id. GIF isn't supported by Roblox (convert it to WebM). To see it behind the content too, make Content panel / Rows see-through in the theme editor",
		Placeholder = "https://... .png / .jpg / .webm",
		Default = self._backgroundSource or "",
		Flag = "MD3_Background",
		Callback = function(text)
			local ok, err = self:SetBackground(text)
			if not ok then
				self:Notify({ Title = "Background unavailable", Content = err or "", Icon = "error" })
				backgroundInput:Set(self._backgroundSource or "", true)
			end
		end,
	})
	local backgroundSlider = backgroundSection:AddSlider({
		Title = "Image transparency",
		Description = "How much of the window color shows through",
		Min = 0,
		Max = 100,
		Step = 1,
		Suffix = "%",
		Default = math.round(self._backgroundTransparency * 100),
		Flag = "MD3_BackgroundTransparency",
		Callback = function(percent)
			self:SetBackgroundTransparency(percent / 100)
		end,
	})
	local backgroundBlur = backgroundSection:AddSlider({
		Title = "Image blur",
		Description = "Softens a background image (not videos)",
		Min = 0,
		Max = MAX_BACKGROUND_BLUR,
		Step = 1,
		Suffix = " px",
		Default = self._backgroundBlur,
		Flag = "MD3_BackgroundBlur",
		Callback = function(pixels)
			self:SetBackgroundBlur(pixels)
		end,
	})
	backgroundSection:AddButton({
		Title = "Remove background",
		Icon = "delete",
		Callback = function()
			self:SetBackground(nil)
		end,
	})
	self._backgroundControls = { Input = backgroundInput, Slider = backgroundSlider, Blur = backgroundBlur }

	self:AddThemeEditor(tab)

	local interface = tab:AddSection("Interface")
	interface:AddKeybind({
		Title = "Toggle UI",
		Description = "Shows / hides this window",
		Default = self._toggleKey,
		Flag = "MD3_ToggleKey",
		Notify = false, -- the window toggle key never shows a toast
		ChangedCallback = function(key)
			self:SetToggleKey(key)
		end,
	})
	-- A startup setting, so it's stored outside configs (which load later).
	if self._loadingAllowed and Env.CanUseFiles then
		interface:AddToggle({
			Title = "Loading animation",
			Description = "Plays when the script starts (from the next run)",
			Default = self:GetLoadingScreenEnabled(),
			Callback = function(on)
				self:SetLoadingScreenEnabled(on)
			end,
		})
	end
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
		Description = "Palette to start from. Custom colors below are kept; NeverLose also sets its own dark colors",
		Options = presetNames,
		Callback = function(name)
			if name then
				theme:ApplyPreset(name)
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
		return { Colors = theme:GetOverrides(), Transparency = theme:GetTransparencies(), Follow = theme:GetFollow() }
	end
	local overridesFlag = { Type = "ThemeOverrides", Flag = "MD3_ThemeOverrides", Value = current() }
	function overridesFlag:Set(value)
		if type(value) ~= "table" then
			theme:ClearOverrides()
		elseif value.Colors or value.Transparency then
			theme:SetOverrides(value.Colors or {}, value.Transparency or {}, value.Follow or {})
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

	pcall(function()
		UserInputService.MouseIconEnabled = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end)
end
Window.Unload = Window.Destroy

return Window
