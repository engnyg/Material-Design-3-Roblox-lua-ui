--[[
	Material 3 Text Field. Variants: "Outlined" (default), "Filled".

	local field = MD3.TextField.new({ Label = "Email", Variant = "Outlined", Parent = form })
	field.Changed:Connect(function(text) ... end)
	field.Submitted:Connect(function(text) ... end)
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

local TextField = {}
TextField.__index = TextField

local HEIGHT = 56

function TextField.new(props)
	props = props or {}
	local self = setmetatable({}, TextField)
	self._maid = Maid.new()
	self._theme = props.Theme or Theme.Default()
	self._variant = props.Variant or "Outlined"
	self._disabled = props.Disabled or false
	self._error = props.Error or false
	self._focused = false
	self.Changed = Signal.new()
	self.Submitted = Signal.new()
	self.FocusChanged = Signal.new()

	local root = Create("Frame") {
		Name = props.Name or "MD3TextField",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = props.Size or UDim2.new(1, 0, 0, 0),
		LayoutOrder = props.LayoutOrder or 0,
	}
	Create("UIListLayout") {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 4),
		Parent = root,
	}

	local container = Create("Frame") {
		Name = "Container",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, HEIGHT),
		LayoutOrder = 1,
		Parent = root,
	}
	local isFilled = self._variant == "Filled"
	Shape.Corner(isFilled and Shape.ExtraSmall or Shape.ExtraSmall, container)
	self._container = container

	local stroke = Create("UIStroke") {
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = container,
	}
	self._stroke = stroke

	if isFilled then
		-- Filled variant gets a bottom "indicator" line instead of a full outline.
		stroke.Thickness = 0
		Create("Frame") {
			Name = "Indicator",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 1),
			BorderSizePixel = 0,
			Parent = container,
		}
		self._indicator = container.Indicator
	end

	Create("UIPadding") {
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
		PaddingTop = UDim.new(0, isFilled and 8 or 0),
		Parent = container,
	}

	local label = Create("TextLabel") {
		Name = "Label",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 0, 16),
		Text = props.Label or "",
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = isFilled,
		Parent = container,
	}
	Typography.Apply(label, "BodySmall")
	self._label = label

	local textBox = Create("TextBox") {
		Name = "Input",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, isFilled and 16 or 0),
		Size = UDim2.new(1, 0, 1, isFilled and -16 or 0),
		ClearTextOnFocus = false,
		Text = props.Text or "",
		PlaceholderText = isFilled and (props.Placeholder or "") or (props.Label or props.Placeholder or ""),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
		MultiLine = props.MultiLine or false,
		Parent = container,
	}
	Typography.Apply(textBox, "BodyLarge")
	self._textBox = textBox

	local supportingText = Create("TextLabel") {
		Name = "SupportingText",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -32, 0, 0),
		Position = UDim2.new(0, 16, 0, 0),
		Text = props.SupportingText or "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Visible = (props.SupportingText or "") ~= "" or self._error,
		LayoutOrder = 2,
		Parent = root,
	}
	Typography.Apply(supportingText, "BodySmall")
	self._supportingText = supportingText

	self.Instance = root

	self:_applyTheme()
	self:_bindInput()

	self._maid:GiveTask(self._theme.Changed:Connect(function()
		self:_applyTheme()
	end))

	if props.Parent then
		root.Parent = props.Parent
	end

	return self
end

function TextField:_applyTheme()
	local c = self._theme.Colors
	local isFilled = self._variant == "Filled"
	local accent = self._error and c.Error or c.Primary

	self._container.BackgroundColor3 = isFilled and c.SurfaceContainerHighest or c.Surface
	self._container.BackgroundTransparency = self._disabled and (isFilled and 0.88 or 1) or (isFilled and 0 or 1)

	self._textBox.TextColor3 = self._disabled and c.OnSurface or c.OnSurface
	self._textBox.TextTransparency = self._disabled and 0.62 or 0
	self._textBox.PlaceholderColor3 = self._disabled and c.OnSurface or c.OnSurfaceVariant

	self._label.TextColor3 = self._disabled and c.OnSurface or (self._focused and accent or c.OnSurfaceVariant)

	local ti = Motion.Standard(Motion.Duration.Short2)
	if isFilled then
		self._indicator.BackgroundColor3 = self._disabled and c.OnSurface or accent
		TweenService:Create(self._indicator, ti, {
			Size = UDim2.new(1, 0, 0, (self._focused or self._error) and 2 or 1),
		}):Play()
	else
		self._stroke.Color = self._disabled and c.OnSurface or accent
		self._stroke.Transparency = self._disabled and 0.62 or 0
		TweenService:Create(self._stroke, ti, {
			Thickness = self._focused and 2 or 1,
		}):Play()
	end

	self._supportingText.TextColor3 = self._error and c.Error or c.OnSurfaceVariant
	self._supportingText.Visible = self._supportingText.Text ~= ""
end

function TextField:_bindInput()
	local textBox = self._textBox

	self._maid:GiveTask(textBox:GetPropertyChangedSignal("Text"):Connect(function()
		self.Changed:Fire(textBox.Text)
	end))
	self._maid:GiveTask(textBox.Focused:Connect(function()
		self._focused = true
		self:_applyTheme()
		self.FocusChanged:Fire(true)
	end))
	self._maid:GiveTask(textBox.FocusLost:Connect(function(enterPressed)
		self._focused = false
		self:_applyTheme()
		self.FocusChanged:Fire(false)
		if enterPressed then
			self.Submitted:Fire(textBox.Text)
		end
	end))
end

function TextField:GetText(): string
	return self._textBox.Text
end

function TextField:SetText(text: string)
	self._textBox.Text = text
end

function TextField:SetError(isError: boolean, message: string?)
	self._error = isError
	if message ~= nil then
		self._supportingText.Text = message
	end
	self:_applyTheme()
end

function TextField:SetSupportingText(text: string)
	self._supportingText.Text = text
	self._supportingText.Visible = text ~= ""
end

function TextField:SetDisabled(disabled: boolean)
	self._disabled = disabled
	self._textBox.TextEditable = not disabled
	self:_applyTheme()
end

function TextField:SetTheme(theme)
	self._theme = theme
	self:_applyTheme()
end

function TextField:Destroy()
	self._maid:Destroy()
	self.Changed:DisconnectAll()
	self.Submitted:DisconnectAll()
	self.FocusChanged:DisconnectAll()
	self.Instance:Destroy()
end

return TextField
