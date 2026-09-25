--[[
	Material 3 Basic Dialog: scrim + centered card with title/text/actions.

	local dialog = MD3.Dialog.new({
		Parent = screenGui,
		Title = "Delete item?",
		Text = "This action cannot be undone.",
		Actions = {
			{ Text = "Cancel", Variant = "Text" },
			{ Text = "Delete", Variant = "Filled", OnActivated = function() ... end },
		},
	})
	dialog:Show()
]]
local TweenService = game:GetService("TweenService")

local Root = script.Parent.Parent
local Create = require(Root.Util.Create)
local Maid = require(Root.Util.Maid)
local Signal = require(Root.Util.Signal)
local Theme = require(Root.Core.Theme)
local Typography = require(Root.Core.Typography)
local Shape = require(Root.Core.Shape)
local Motion = require(Root.Core.Motion)
local Elevation = require(Root.Core.Elevation)
local Button = require(Root.Components.Button)

local Dialog = {}
Dialog.__index = Dialog

function Dialog.new(props)
	props = props or {}
	local self = setmetatable({}, Dialog)
	self._maid = Maid.new()
	self._theme = props.Theme or Theme.Default()
	self._buttons = {}
	self.Dismissed = Signal.new()

	local scrim = Create("TextButton") {
		Name = props.Name or "MD3Dialog",
		AutoButtonColor = false,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = props.ZIndex or 100,
	}

	-- A TextButton (not a Frame) so clicks on the card are caught here and
	-- don't fall through to the scrim, which dismisses the dialog.
	local card = Create("TextButton") {
		Name = "Card",
		AutoButtonColor = false,
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = props.Size or UDim2.new(0, 320, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		ZIndex = scrim.ZIndex + 1,
		Parent = scrim,
	}
	Shape.Corner(Shape.ExtraLarge, card)
	Create("UIPadding") {
		PaddingTop = UDim.new(0, 24),
		PaddingBottom = UDim.new(0, 24),
		PaddingLeft = UDim.new(0, 24),
		PaddingRight = UDim.new(0, 24),
		Parent = card,
	}
	Create("UIListLayout") {
		SortOrder = Enum.SortOrder.LayoutOrder, -- the default sorts by Name
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 16),
		Parent = card,
	}
	self._card = card

	local title = Create("TextLabel") {
		Name = "Title",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Text = props.Title or "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		LayoutOrder = 1,
		ZIndex = card.ZIndex,
		Parent = card,
	}
	Typography.Apply(title, "HeadlineSmall")
	self._title = title

	local body = Create("TextLabel") {
		Name = "Body",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Text = props.Text or "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		LayoutOrder = 2,
		ZIndex = card.ZIndex,
		Parent = card,
	}
	Typography.Apply(body, "BodyMedium")
	self._body = body

	local actionsRow = Create("Frame") {
		Name = "Actions",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 3,
		ZIndex = card.ZIndex,
		Parent = card,
	}
	Create("UIListLayout") {
		SortOrder = Enum.SortOrder.LayoutOrder, -- the default sorts by Name
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 8),
		Parent = actionsRow,
	}

	for index, action in ipairs(props.Actions or {}) do
		local btn = Button.new({
			Text = action.Text,
			Variant = action.Variant or "Text",
			Theme = self._theme,
			LayoutOrder = index,
			Parent = actionsRow,
		})
		btn.Instance.ZIndex = card.ZIndex
		btn.Activated:Connect(function()
			if action.OnActivated then
				action.OnActivated()
			end
			if action.DismissOnActivate ~= false then
				self:Hide()
			end
		end)
		table.insert(self._buttons, btn)
	end

	self.Instance = scrim

	self:_applyTheme()
	self._maid:GiveTask(self._theme.Changed:Connect(function()
		self:_applyTheme()
	end))

	if props.DismissOnScrimClick ~= false then
		self._maid:GiveTask(scrim.Activated:Connect(function()
			self:Hide()
		end))
	end

	if props.Parent then
		scrim.Parent = props.Parent
	end

	return self
end

function Dialog:_applyTheme()
	local c = self._theme.Colors
	self.Instance.BackgroundColor3 = c.Scrim
	self._card.BackgroundColor3 = c.SurfaceContainerHigh
	self._title.TextColor3 = c.OnSurface
	self._body.TextColor3 = c.OnSurfaceVariant
	Elevation.Apply(self._card, 3, c.Shadow, Shape.ExtraLarge)
end

function Dialog:Show()
	local scrim = self.Instance
	scrim.Visible = true
	scrim.BackgroundTransparency = 1
	self._card.Size = UDim2.new(0, self._card.AbsoluteSize.X, 0, 0)

	TweenService:Create(scrim, Motion.Standard(Motion.Duration.Short3), { BackgroundTransparency = 0.68 }):Play()
end

function Dialog:Hide()
	local scrim = self.Instance
	local tween = TweenService:Create(scrim, Motion.Standard(Motion.Duration.Short2), { BackgroundTransparency = 1 })
	tween:Play()
	tween.Completed:Once(function()
		scrim.Visible = false
		self.Dismissed:Fire()
	end)
end

function Dialog:SetTheme(theme)
	self._theme = theme
	self:_applyTheme()
	for _, btn in self._buttons do
		btn:SetTheme(theme)
	end
end

function Dialog:Destroy()
	Elevation.Remove(self._card)
	self._maid:Destroy()
	for _, btn in self._buttons do
		btn:Destroy()
	end
	self.Dismissed:DisconnectAll()
	self.Instance:Destroy()
end

return Dialog
