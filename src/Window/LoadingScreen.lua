--[[
	Startup loading screen for executor windows: an M3 card with the app
	icon, title, a progress bar and a status line. It waits (up to a
	timeout) for the Material icon images, then fades out and hands over to
	the window. Driven by Heartbeat rather than task.wait so it never blocks
	the script: CreateWindow returns at once and tabs are built underneath.

	Options (CreateWindow{ LoadingScreen = { ... } }; `true` = defaults):
		Title = window title, Subtitle = window subtitle,
		Icon = window icon / logo, Duration = 1.2 (minimum seconds shown)
]]
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Root = script.Parent.Parent
local Create = require(Root.Util.Create)
local Maid = require(Root.Util.Maid)
local Typography = require(Root.Core.Typography)
local Shape = require(Root.Core.Shape)
local Motion = require(Root.Core.Motion)
local Base = require(script.Parent.Elements.Base)

local LoadingScreen = {}

local WIDTH = 300
local ICON_TIMEOUT = 5 -- stop waiting for the icon images after this long
local DEFAULT_DURATION = 1.2

function LoadingScreen.Run(window, opts, onDone)
	opts = if type(opts) == "table" then opts else {}
	local themer = window._themer
	local maid = Maid.new()
	window._maid:GiveTask(maid)
	local minDuration = opts.Duration or DEFAULT_DURATION

	-- A CanvasGroup so the whole card fades as one.
	local card = Create("CanvasGroup") {
		Name = "Loading",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		ZIndex = 80,
		[1] = Create("UIPadding") {
			PaddingTop = UDim.new(0, 28),
			PaddingBottom = UDim.new(0, 24),
			PaddingLeft = UDim.new(0, 24),
			PaddingRight = UDim.new(0, 24),
		},
		[2] = Create("UIListLayout") {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		},
	}
	Shape.Corner(Shape.ExtraLarge, card)
	themer:Bind(card, { BackgroundColor3 = "SurfaceContainerHigh" })
	local scale = Create("UIScale") { Scale = window._uiScale.Scale * 0.92, Parent = card }
	maid:GiveTask(card)

	local iconSource = opts.Icon or window._appIconSource
	if iconSource and Base.CanShowIcon(iconSource) then
		local tint = opts.Icon ~= nil or window._appIconTint
		local icon = Base.Glyph(themer, iconSource, 40, "IconAccent", card, tint)
		icon.LayoutOrder = 1
	end

	local function text(name: string, value: string, role: string, color: string, order: number)
		local label = Create("TextLabel") {
			Name = name,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = value,
			TextWrapped = true,
			LayoutOrder = order,
			Parent = card,
		}
		Typography.Apply(label, role)
		themer:Bind(label, { TextColor3 = color })
		return label
	end
	text("Title", opts.Title or window.Title, "TitleLarge", "OnSurface", 2)
	local subtitle = opts.Subtitle or window._subtitleLabel.Text
	if subtitle ~= "" then
		text("Subtitle", subtitle, "BodyMedium", "OnSurfaceVariant", 3)
	end

	local track = Create("Frame") {
		Name = "Progress",
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 4),
		LayoutOrder = 4,
		Parent = card,
		[1] = Create("UICorner") { CornerRadius = UDim.new(1, 0) },
	}
	themer:Bind(track, { BackgroundColor3 = "SecondaryContainer" })
	local fill = Create("Frame") {
		Name = "Bar",
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
		[1] = Create("UICorner") { CornerRadius = UDim.new(1, 0) },
	}
	themer:Bind(fill, { BackgroundColor3 = "Primary" })
	local status = text("Status", "Loading icons…", "LabelMedium", "OnSurfaceVariant", 5)

	card.Parent = window.Gui

	local controller = { Instance = card, Progress = 0, Finished = false }
	local function setProgress(value: number)
		controller.Progress = value
		fill.Size = UDim2.fromScale(value, 1)
	end

	TweenService:Create(card, Motion.Emphasized(Motion.Duration.Medium2), { GroupTransparency = 0 }):Play()
	TweenService:Create(scale, Motion.Emphasized(Motion.Duration.Medium2), { Scale = window._uiScale.Scale }):Play()

	local function finish()
		if controller.Finished then
			return
		end
		controller.Finished = true
		maid:Remove(controller._stepKey)
		setProgress(1)
		status.Text = "Ready"
		local out = TweenService:Create(card, Motion.Accelerate(Motion.Duration.Short4), { GroupTransparency = 1 })
		TweenService:Create(scale, Motion.Accelerate(Motion.Duration.Short4), { Scale = window._uiScale.Scale * 1.04 }):Play()
		out:Play()
		out.Completed:Once(function()
			maid:Destroy()
			onDone()
		end)
	end
	controller.Finish = finish -- skip the rest of the wait

	-- Creeps toward 70 % while the icons load, then runs to 100 % once they
	-- are in (or the timeout passes) and the minimum time is up.
	local elapsed = 0
	controller._stepKey = maid:GiveTask(RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local iconsReady = window._iconsReady or elapsed >= ICON_TIMEOUT
		if iconsReady then
			status.Text = "Starting…"
			setProgress(math.max(controller.Progress, math.min(1, elapsed / math.max(minDuration, 1e-3))))
		else
			setProgress(0.7 * (1 - math.exp(-elapsed * 1.5)))
		end
		if iconsReady and elapsed >= minDuration then
			finish()
		end
	end))

	return controller
end

return LoadingScreen
