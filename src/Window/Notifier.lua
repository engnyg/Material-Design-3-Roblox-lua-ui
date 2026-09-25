-- Stacked toast notifications for executor windows (bottom-right corner).
-- Unlike Snackbar (one message at a time) these queue up and each carries
-- its own title, text, icon and countdown bar.
local TweenService = game:GetService("TweenService")

local Root = script.Parent.Parent
local Create = require(Root.Util.Create)
local Typography = require(Root.Core.Typography)
local Shape = require(Root.Core.Shape)
local Motion = require(Root.Core.Motion)
local Base = require(script.Parent.Elements.Base)

local Notifier = {}
Notifier.__index = Notifier

local WIDTH = 300

function Notifier.new(parent: Instance, themer)
	local self = setmetatable({}, Notifier)
	self._themer = themer
	self._count = 0

	self.Instance = Create("Frame") {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0, WIDTH, 1, -32),
		BackgroundTransparency = 1,
		ZIndex = 50,
		[1] = Create("UIListLayout") {
			FillDirection = Enum.FillDirection.Vertical,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		},
		Parent = parent,
	}
	return self
end

-- Notify({ Title = "Saved", Content = "Config written", Icon = "save", Duration = 5 })
-- IconColor: a theme role or a Color3 (default "IconAccent").
function Notifier:Notify(props)
	if type(props) == "string" then
		props = { Title = props }
	end
	local themer = self._themer
	local duration = props.Duration or 5
	self._count += 1

	-- The slot takes part in the list layout; the card inside it slides.
	local slot = Create("Frame") {
		Name = "Notification",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = self._count,
		ZIndex = 50,
		Parent = self.Instance,
	}

	local card = Create("TextButton") {
		Name = "Card",
		AutoButtonColor = false,
		Text = "",
		Position = UDim2.new(1, 24, 0, 0),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 50,
		Parent = slot,
	}
	Shape.Corner(Shape.Medium, card)
	themer:Bind(card, { BackgroundColor3 = "SurfaceContainerHighest" })
	themer:Bind(Create("UIStroke") {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 1,
		Parent = card,
	}, { Color = "OutlineVariant" })
	Create("UIPadding") {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
		Parent = card,
	}

	-- Icon: Material icon name or image (URL / rbxassetid); Image: a colored
	-- image that isn't tinted.
	local iconName = props.Image or props.Icon or "notifications"
	local hasIcon = props.Icon ~= false and Base.CanShowIcon(iconName)
	if hasIcon then
		local icon = Base.Glyph(themer, iconName, 20, props.IconColor or "IconAccent", card, props.Image == nil)
		icon.ZIndex = 51
		if icon:IsA("ImageLabel") and not icon.Visible then
			hasIcon = false
		end
	end

	local textColumn = Create("Frame") {
		Name = "Text",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(hasIcon and 32 or 0, 0),
		Size = UDim2.new(1, hasIcon and -32 or 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 51,
		[1] = Create("UIListLayout") {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		},
		Parent = card,
	}

	local title = Create("TextLabel") {
		Name = "Title",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = props.Title or "",
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		ZIndex = 51,
		Parent = textColumn,
	}
	Typography.Apply(title, "TitleSmall")
	themer:Bind(title, { TextColor3 = "OnSurface" })

	if props.Content and props.Content ~= "" then
		local body = Create("TextLabel") {
			Name = "Content",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = props.Content,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2,
			ZIndex = 51,
			Parent = textColumn,
		}
		Typography.Apply(body, "BodyMedium")
		themer:Bind(body, { TextColor3 = "OnSurfaceVariant" })
	end

	-- Countdown bar under the text (a layout item, so it can't feed back
	-- into the card's automatic height).
	local countdown = Create("Frame") {
		Name = "Countdown",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 11),
		LayoutOrder = 3,
		ZIndex = 51,
		Parent = textColumn,
	}
	local bar = Create("Frame") {
		Name = "Bar",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 3),
		BorderSizePixel = 0,
		ZIndex = 52,
		[1] = Create("UICorner") { CornerRadius = UDim.new(1, 0) },
		Parent = countdown,
	}
	themer:Bind(bar, { BackgroundColor3 = "Primary" })

	TweenService:Create(card, Motion.Emphasized(Motion.Duration.Medium2), { Position = UDim2.new() }):Play()
	TweenService:Create(bar, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 3) }):Play()

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		local out = TweenService:Create(card, Motion.Accelerate(Motion.Duration.Short4), { Position = UDim2.new(1, 24, 0, 0) })
		out:Play()
		out.Completed:Once(function()
			slot:Destroy()
		end)
	end

	card.Activated:Connect(close)
	task.delay(duration, close)

	return { Close = close, Instance = slot }
end

function Notifier:Destroy()
	self.Instance:Destroy()
end

return Notifier
