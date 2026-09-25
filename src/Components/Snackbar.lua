--[[
	Material 3 Snackbar: transient bottom message with an optional action.

	local snackbar = MD3.Snackbar.new({ Parent = screenGui })
	snackbar:Show("Message sent", { Text = "Undo", OnActivated = function() end }, 4)
]]
local TweenService = game:GetService("TweenService")

local Root = script.Parent.Parent
local Create = require(Root.Util.Create)
local Maid = require(Root.Util.Maid)
local Theme = require(Root.Core.Theme)
local Typography = require(Root.Core.Typography)
local Shape = require(Root.Core.Shape)
local Motion = require(Root.Core.Motion)
local Elevation = require(Root.Core.Elevation)
local Button = require(Root.Components.Button)

local Snackbar = {}
Snackbar.__index = Snackbar

function Snackbar.new(props)
	props = props or {}
	local self = setmetatable({}, Snackbar)
	self._maid = Maid.new()
	self._theme = props.Theme or Theme.Default()
	self._hideToken = 0

	local root = Create("Frame") {
		Name = props.Name or "MD3Snackbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 24),
		AutomaticSize = Enum.AutomaticSize.XY,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = props.ZIndex or 100,
	}
	Shape.Corner(Shape.ExtraSmall, root)
	Create("UIPadding") {
		PaddingTop = UDim.new(0, 14),
		PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 8),
		Parent = root,
	}
	Create("UIListLayout") {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		Parent = root,
	}

	local label = Create("TextLabel") {
		Name = "Label",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 20),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = root.ZIndex,
		Parent = root,
	}
	Typography.Apply(label, "BodyMedium")
	self._label = label
	self._actionButton = nil

	self.Instance = root

	self:_applyTheme()
	self._maid:GiveTask(self._theme.Changed:Connect(function()
		self:_applyTheme()
	end))

	if props.Parent then
		root.Parent = props.Parent
	end

	return self
end

function Snackbar:_applyTheme()
	local c = self._theme.Colors
	self.Instance.BackgroundColor3 = c.InverseSurface
	self._label.TextColor3 = c.InverseOnSurface
	Elevation.Apply(self.Instance, 3, c.Shadow, Shape.ExtraSmall)
	if self._actionButton then
		self._actionButton:SetVariant("Text")
	end
end

function Snackbar:Show(message: string, action, duration: number?)
	self._hideToken += 1
	local token = self._hideToken

	self._label.Text = message

	if self._actionButton then
		self._actionButton:Destroy()
		self._actionButton = nil
	end
	if action then
		self._actionButton = Button.new({
			Text = action.Text,
			Variant = "Text",
			Theme = self._theme,
			Parent = self.Instance,
		})
		self._actionButton.Instance.ZIndex = self.Instance.ZIndex
		-- Snackbar action buttons use the inverse-primary color on the inverse surface.
		self._actionButton._label.TextColor3 = self._theme.Colors.InversePrimary
		if action.OnActivated then
			self._actionButton.Activated:Connect(action.OnActivated)
		end
	end

	local root = self.Instance
	root.Visible = true
	root.Position = UDim2.new(0.5, 0, 1, 24)
	TweenService:Create(root, Motion.Emphasized(Motion.Duration.Medium2), {
		Position = UDim2.new(0.5, 0, 1, -24),
	}):Play()

	task.delay(duration or 4, function()
		if token == self._hideToken then
			self:Hide()
		end
	end)
end

function Snackbar:Hide()
	self._hideToken += 1
	local root = self.Instance
	local tween = TweenService:Create(root, Motion.Standard(Motion.Duration.Short3), {
		Position = UDim2.new(0.5, 0, 1, 24),
	})
	tween:Play()
	tween.Completed:Once(function()
		root.Visible = false
	end)
end

function Snackbar:SetTheme(theme)
	self._theme = theme
	self:_applyTheme()
	if self._actionButton then
		self._actionButton:SetTheme(theme)
	end
end

function Snackbar:Destroy()
	Elevation.Remove(self.Instance)
	self._maid:Destroy()
	if self._actionButton then
		self._actionButton:Destroy()
	end
	self.Instance:Destroy()
end

return Snackbar
