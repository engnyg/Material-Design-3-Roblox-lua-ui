--[[
	Tab:AddColorPicker({
		Title = "ESP color",
		Default = Color3.fromRGB(255, 80, 80),
		Flag = "EspColor",
		Callback = function(color) end,
	})

	Click the row's header to open (animated) a saturation/value square, a
	hue bar and a hex field; :SetExpanded(open) does it from code.

	Transparency: pass Transparency = 0..1 (or Alpha = true) to add an
	opacity bar. The callback then gets (color, transparency), .Transparency
	holds the current value, :Set accepts { Color = c, Transparency = t },
	and both are saved in configs.
]]
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Root = script.Parent.Parent.Parent
local Base = require(script.Parent.Base)
local Create = require(Root.Util.Create)
local Typography = require(Root.Core.Typography)
local Shape = require(Root.Core.Shape)
local Motion = require(Root.Core.Motion)

local PICKER_HEIGHT = 128
local HUE_WIDTH = 16
local ALPHA_HEIGHT = 16

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

return function(container, props)
	local element = Base.Element(container, props, "ColorPicker")
	local window = element._window
	local themer = window._themer

	local alphaEnabled = props.Transparency ~= nil or props.Alpha == true
	element.Transparency = if alphaEnabled then math.clamp(props.Transparency or 0, 0, 1) else 0

	local function normalize(value)
		if type(value) == "table" then
			-- { Color = Color3, Transparency = number } (also what configs store)
			if alphaEnabled and type(value.Transparency) == "number" then
				element.Transparency = math.clamp(value.Transparency, 0, 1)
			end
			value = value.Color
		end
		if typeof(value) == "Color3" then
			return value
		elseif type(value) == "string" then
			local ok, color = pcall(Color3.fromHex, value)
			if ok then
				return color
			end
		end
		return element.Value or Color3.new(1, 1, 1)
	end

	element.Value = normalize(props.Default or props.Value or props.Color)
	local hue, sat, val = element.Value:ToHSV()

	local row = Base.Row(element, props, { ClassName = "TextButton", ControlWidth = 44, ControlHeight = 28 })
	-- Press feedback only on the header, not over the picker once it's open.
	local _, onHeader = Base.Interactive(element, row.Frame, nil, { Header = row })

	local swatch = Create("Frame") {
		Name = "Swatch",
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = element.Value,
		Parent = row.Control,
	}
	Shape.Corner(Shape.Small, swatch)
	themer:Bind(Create("UIStroke") {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 1,
		Parent = swatch,
	}, { Color = "Outline" })

	-- Rows below the square: [opacity bar] then hex / RGB.
	local infoY = PICKER_HEIGHT + 10 + (if alphaEnabled then ALPHA_HEIGHT + 10 else 0)
	local panelHeight = infoY + 30
	local panel = row.Extra(false)
	panel.Size = UDim2.new(1, 0, 0, 0)
	panel.AutomaticSize = Enum.AutomaticSize.None

	-- Saturation (x) / value (y) square: hue background, a white->clear
	-- gradient left to right, then a clear->black gradient top to bottom.
	local svBox = Create("TextButton") {
		Name = "SaturationValue",
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		Size = UDim2.new(1, -(HUE_WIDTH + 12), 0, PICKER_HEIGHT),
		Parent = panel,
	}
	Shape.Corner(Shape.Small, svBox)
	local whiteLayer = Create("Frame") {
		Name = "Saturation",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = svBox,
		[1] = Create("UIGradient") {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		},
	}
	Shape.Corner(Shape.Small, whiteLayer)
	local blackLayer = Create("Frame") {
		Name = "Value",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = svBox,
		[1] = Create("UIGradient") {
			Rotation = 90,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
		},
	}
	Shape.Corner(Shape.Small, blackLayer)
	local svCursor = Create("Frame") {
		Name = "Cursor",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(14, 14),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = svBox,
		[1] = Create("UICorner") { CornerRadius = UDim.new(1, 0) },
		[2] = Create("UIStroke") { Color = Color3.new(1, 1, 1), Thickness = 2 },
	}

	local hueKeypoints = {}
	for i = 0, 6 do
		table.insert(hueKeypoints, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((i / 6) % 1, 1, 1)))
	end
	local hueBar = Create("TextButton") {
		Name = "Hue",
		AutoButtonColor = false,
		Text = "",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(HUE_WIDTH, PICKER_HEIGHT),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = panel,
		[1] = Create("UIGradient") { Rotation = 90, Color = ColorSequence.new(hueKeypoints) },
	}
	Shape.Corner(Shape.Full, hueBar)
	local hueCursor = Create("Frame") {
		Name = "Cursor",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 6, 0, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = hueBar,
		[1] = Create("UICorner") { CornerRadius = UDim.new(1, 0) },
	}
	themer:Bind(Create("UIStroke") { Thickness = 1, Parent = hueCursor }, { Color = "Outline" })

	-- Opacity bar: the current color fading from see-through (left) to
	-- solid (right) over an outline-colored track, so the fade is visible.
	local alphaBar, alphaFill, alphaCursor = nil, nil, nil
	if alphaEnabled then
		alphaBar = Create("TextButton") {
			Name = "Opacity",
			AutoButtonColor = false,
			Text = "",
			Position = UDim2.fromOffset(0, PICKER_HEIGHT + 10),
			Size = UDim2.new(1, 0, 0, ALPHA_HEIGHT),
			BorderSizePixel = 0,
			Parent = panel,
		}
		Shape.Corner(Shape.Full, alphaBar)
		themer:Bind(alphaBar, { BackgroundColor3 = "OutlineVariant" })
		alphaFill = Create("Frame") {
			Name = "Fill",
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Parent = alphaBar,
			[1] = Create("UIGradient") {
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
			},
		}
		Shape.Corner(Shape.Full, alphaFill)
		alphaCursor = Create("Frame") {
			Name = "Cursor",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(6, ALPHA_HEIGHT + 6),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = alphaBar,
			[1] = Create("UICorner") { CornerRadius = UDim.new(1, 0) },
		}
		themer:Bind(Create("UIStroke") { Thickness = 1, Parent = alphaCursor }, { Color = "Outline" })
	end

	local hexBox = Base.Field(themer, "TextBox", panel, UDim2.fromOffset(120, 28))
	hexBox.Position = UDim2.fromOffset(0, infoY)
	hexBox.ClearTextOnFocus = false
	hexBox.TextXAlignment = Enum.TextXAlignment.Left
	Typography.Apply(hexBox, "BodyMedium")
	themer:Bind(hexBox, { TextColor3 = "OnSurface" })
	Create("UIPadding") { PaddingLeft = UDim.new(0, 10), Parent = hexBox }

	local rgbLabel = Create("TextLabel") {
		Name = "RGB",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(132, infoY),
		Size = UDim2.new(1, -132, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	}
	Typography.Apply(rgbLabel, "BodySmall")
	themer:Bind(rgbLabel, { TextColor3 = "OnSurfaceVariant" })

	local function paint()
		local color = element.Value
		swatch.BackgroundColor3 = color
		swatch.BackgroundTransparency = element.Transparency
		svBox.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		svCursor.BackgroundColor3 = color
		svCursor.Position = UDim2.fromScale(sat, 1 - val)
		hueCursor.Position = UDim2.fromScale(0.5, hue)
		hexBox.Text = "#" .. color:ToHex():upper()
		rgbLabel.Text = string.format(
			"RGB %d, %d, %d",
			math.round(color.R * 255),
			math.round(color.G * 255),
			math.round(color.B * 255)
		)
		if alphaEnabled then
			alphaFill.BackgroundColor3 = color
			alphaCursor.Position = UDim2.fromScale(1 - element.Transparency, 0.5)
			rgbLabel.Text ..= string.format(" · Opacity %d%%", math.round((1 - element.Transparency) * 100))
		end
	end

	if alphaEnabled then
		-- Callback / Changed get (color, transparency).
		function element:_emit(color)
			self.Changed:Fire(color, self.Transparency)
			if self._callback then
				window:_call(self._callback, color, self.Transparency)
			end
		end

		-- What configs store for this picker.
		function element:GetSaveValue()
			return { Color = self.Value, Transparency = self.Transparency }
		end
	end

	-- Sets only the transparency (0 = solid, 1 = invisible).
	function element:SetTransparency(transparency: number, silent: boolean?)
		self:Set({ Color = self.Value, Transparency = transparency }, silent)
	end

	local function commit()
		element.Value = Color3.fromHSV(hue, sat, val)
		paint()
		element:_emit(element.Value)
	end

	element._normalize = normalize
	element._render = function(color)
		-- Keep the current hue for greys, where ToHSV can't recover one.
		local h, s, v = color:ToHSV()
		if s > 0 then
			hue = h
		end
		sat, val = s, v
		paint()
	end

	-- Opens / closes by growing / shrinking the panel (the row follows its
	-- height). Content is clipped only while it moves, so the cursors can
	-- poke past the square's edges once it's open.
	element.Expanded = false
	local motion = nil
	function element:SetExpanded(open: boolean)
		if open == element.Expanded then
			return
		end
		element.Expanded = open
		-- Completed also fires for a cancelled tween; clearing `motion` first
		-- lets its handler (below) see it was replaced and do nothing.
		local previous = motion
		motion = nil
		if previous then
			previous:Cancel()
		end
		panel.ClipsDescendants = true
		panel.Visible = true
		if open then
			motion = TweenService:Create(panel, Motion.Emphasized(Motion.Duration.Medium2), { Size = UDim2.new(1, 0, 0, panelHeight) })
		else
			motion = TweenService:Create(panel, Motion.Emphasized(Motion.Duration.Short4), { Size = UDim2.new(1, 0, 0, 0) })
		end
		local thisMotion = motion
		motion.Completed:Once(function()
			if motion ~= thisMotion then
				return
			end
			motion = nil
			panel.ClipsDescendants = false
			panel.Visible = element.Expanded
		end)
		motion:Play()
	end

	-- Only a press that started on the header toggles it: taps on the open
	-- picker's gaps shouldn't fold it away under your finger.
	local pressedHeader = false
	element._maid:GiveTask(row.Frame.InputBegan:Connect(function(input)
		if isPress(input) then
			pressedHeader = onHeader(input)
		end
	end))
	element._maid:GiveTask(row.Frame.Activated:Connect(function()
		if pressedHeader then
			element:SetExpanded(not element.Expanded)
		end
		pressedHeader = false
	end))

	local dragging = nil
	local function updateFrom(input)
		if dragging == "sv" then
			local pos, size = svBox.AbsolutePosition, svBox.AbsoluteSize
			sat = math.clamp((input.Position.X - pos.X) / math.max(size.X, 1), 0, 1)
			val = 1 - math.clamp((input.Position.Y - pos.Y) / math.max(size.Y, 1), 0, 1)
		elseif dragging == "hue" then
			local pos, size = hueBar.AbsolutePosition, hueBar.AbsoluteSize
			hue = math.clamp((input.Position.Y - pos.Y) / math.max(size.Y, 1), 0, 0.999)
		elseif dragging == "alpha" then
			local pos, size = alphaBar.AbsolutePosition, alphaBar.AbsoluteSize
			element.Transparency = 1 - math.clamp((input.Position.X - pos.X) / math.max(size.X, 1), 0, 1)
		end
		commit()
	end

	element._maid:GiveTask(svBox.InputBegan:Connect(function(input)
		if isPress(input) then
			dragging = "sv"
			updateFrom(input)
		end
	end))
	element._maid:GiveTask(hueBar.InputBegan:Connect(function(input)
		if isPress(input) then
			dragging = "hue"
			updateFrom(input)
		end
	end))
	if alphaBar then
		element._maid:GiveTask(alphaBar.InputBegan:Connect(function(input)
			if isPress(input) then
				dragging = "alpha"
				updateFrom(input)
			end
		end))
	end
	element._maid:GiveTask(UserInputService.InputChanged:Connect(function(input)
		if dragging and isMove(input) then
			updateFrom(input)
		end
	end))
	element._maid:GiveTask(UserInputService.InputEnded:Connect(function(input)
		if isPress(input) then
			dragging = nil
		end
	end))
	element._maid:GiveTask(hexBox.FocusLost:Connect(function()
		local ok, color = pcall(Color3.fromHex, (hexBox.Text:gsub("[^%x]", "")))
		if ok then
			element:Set(color)
		else
			paint()
		end
	end))

	paint()
	return Base.Finish(element)
end
