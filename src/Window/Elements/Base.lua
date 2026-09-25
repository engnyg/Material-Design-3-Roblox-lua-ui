-- Shared plumbing for executor-window elements: the common element object
-- (Value / Set / Get / Flag / Callback), the M3 list-item row every element
-- is laid out in, and small glyph/state-layer helpers.
local UserInputService = game:GetService("UserInputService")

local Root = script.Parent.Parent.Parent
local Create = require(Root.Util.Create)
local Maid = require(Root.Util.Maid)
local Signal = require(Root.Util.Signal)
local Typography = require(Root.Core.Typography)
local Shape = require(Root.Core.Shape)
local StateLayer = require(Root.Core.StateLayer)
local Ripple = require(Root.Core.Ripple)
local Icons = require(Root.Core.Icons)
local Assets = require(Root.Executor.Assets)

local Base = {}

local Element = {}
Element.__index = Element
Base.ElementClass = Element

function Base.Element(container, props, kind: string)
	local window = container._window
	local self = setmetatable({
		Type = kind,
		Flag = props.Flag,
		Value = nil,
		Changed = Signal.new(),
		_window = window,
		_container = container,
		_maid = Maid.new(),
		_callback = props.Callback,
	}, Element)
	return self
end

function Element:Get()
	return self.Value
end

-- Sets the value, updates the visuals and (unless `silent`) fires Changed
-- and the element's Callback — same path as a user interaction.
function Element:Set(value, silent: boolean?)
	if self._normalize then
		value = self._normalize(value)
	end
	self.Value = value
	if self._render then
		self._render(value)
	end
	if not silent then
		self:_emit(value)
	end
end

function Element:_emit(...)
	self.Changed:Fire(...)
	if self._callback then
		self._window:_call(self._callback, ...)
	end
end

function Element:OnChanged(fn)
	return self.Changed:Connect(fn)
end

function Element:SetCallback(fn)
	self._callback = fn
end

function Element:SetVisible(visible: boolean)
	self.Instance.Visible = visible
end

function Element:SetTitle(text: string)
	if self._title then
		self._title.Text = text
	end
end

function Element:SetDescription(text: string?)
	if self._desc then
		self._desc.Text = text or ""
		self._desc.Visible = (text or "") ~= ""
	end
end

function Element:Destroy()
	if self.Flag and self._window.Flags[self.Flag] == self then
		self._window.Flags[self.Flag] = nil
	end
	self._maid:Destroy()
	self.Changed:DisconnectAll()
	if self.Instance then
		self.Instance:Destroy()
	end
end

-- Registers the element under its Flag (if any) and returns it.
function Base.Finish(element)
	if element.Flag then
		element._window.Flags[element.Flag] = element
	end
	return element
end

-- An icon: either an image (URL / rbxassetid / workspace file, loaded via
-- Assets) as an ImageLabel, or a Material icon name as a glyph TextLabel.
-- Hidden when it can't be drawn. `role` tints it: a theme color role name
-- ("Icon", "Primary", ...) or a fixed Color3. Pass tint = false to keep a
-- colored image (e.g. a logo) as-is.
function Base.Glyph(themer, name, size: number, role, parent: Instance?, tint: boolean?)
	if Assets.IsImage(name) then
		local image = Create("ImageLabel") {
			Name = "Icon",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(size, size),
			Image = Assets.Resolve(name),
			ScaleType = Enum.ScaleType.Fit,
			Parent = parent,
		}
		image.Visible = image.Image ~= ""
		if role and tint ~= false then
			themer:Bind(image, { ImageColor3 = role })
		end
		return image
	end

	local label = Create("TextLabel") {
		Name = "Icon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		TextSize = size,
		Font = Enum.Font.GothamMedium,
		Visible = Icons.CanRender(name),
		Parent = parent,
	}
	-- Icons manages Visible: hidden while no source can draw the icon, shown
	-- once the icon images (or a font) arrive.
	Icons.Apply(label, name, true)
	if role then
		themer:Bind(label, { TextColor3 = role })
	end
	return label
end
Base.Icon = Base.Glyph

-- True for images and for any icon that can be drawn now or once the icon
-- images finish loading.
function Base.CanShowIcon(icon): boolean
	return Assets.IsImage(icon) or Icons.CanRender(icon) or (type(icon) == "string" and Icons.Codepoints[icon] ~= nil)
end

-- Colors an icon made by Base.Glyph, whichever kind it is (optionally
-- with a transparency, 0 = solid).
function Base.SetIconColor(icon: GuiObject, color: Color3, transparency: number?)
	if icon:IsA("ImageLabel") then
		icon.ImageColor3 = color
		icon.ImageTransparency = transparency or 0
	else
		icon.TextColor3 = color
		icon.TextTransparency = transparency or 0
	end
end

--[[
	Lays out an M3 list item:

	┌──────────────────────────────────────────────┐
	│ Title                              [control] │  <- Header
	│ Description                                  │
	│ [extra content, e.g. slider / dropdown list] │  <- :Extra()
	└──────────────────────────────────────────────┘

	opts.ClassName: "Frame" | "TextButton" (whole row clickable)
	opts.ControlWidth / opts.ControlHeight: size of the right-hand slot
]]
function Base.Row(element, props, opts)
	opts = opts or {}
	local container = element._container
	local themer = element._window._themer
	local controlWidth = opts.ControlWidth or 0
	local controlHeight = opts.ControlHeight or 0

	local frame = Create(opts.ClassName or "Frame") {
		Name = props.Title or element.Type,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = container:_nextOrder(),
	}
	if frame:IsA("TextButton") then
		frame.AutoButtonColor = false
		frame.Text = ""
		frame.ClipsDescendants = true -- keeps ripples inside the rounded row
	end
	Shape.Corner(Shape.Medium, frame)
	themer:Bind(frame, { BackgroundColor3 = "SurfaceContainerHigh" })

	-- Padding + list layout live on an inner frame so overlays parented to
	-- the row itself (state layer, ripples) aren't pulled into the layout.
	local body = Create("Frame") {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		[1] = Create("UIPadding") {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 12),
		},
		[2] = Create("UIListLayout") {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		},
		Parent = frame,
	}

	local header = Create("Frame") {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, math.max(controlHeight, 24)),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = body,
	}
	Create("UIListLayout") {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 12),
		Parent = header,
	}

	local text = Create("Frame") {
		Name = "Text",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, controlWidth > 0 and -(controlWidth + 12) or 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = header,
	}
	Create("UIListLayout") {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
		Parent = text,
	}

	local title = Create("TextLabel") {
		Name = "Title",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = props.Title or props.Name or "",
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		Parent = text,
	}
	Typography.Apply(title, "BodyLarge")
	themer:Bind(title, { TextColor3 = "OnSurface" })

	local descText = props.Description or props.Desc or props.Content or ""
	local desc = Create("TextLabel") {
		Name = "Description",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = descText,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = descText ~= "",
		LayoutOrder = 2,
		Parent = text,
	}
	Typography.Apply(desc, "BodyMedium")
	themer:Bind(desc, { TextColor3 = "OnSurfaceVariant" })

	local control = nil
	if controlWidth > 0 then
		control = Create("Frame") {
			Name = "Control",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(controlWidth, controlHeight),
			LayoutOrder = 2,
			Parent = header,
		}
	end

	element.Instance = frame
	element._title = title
	element._desc = desc
	frame.Parent = container._holder

	local row = { Frame = frame, Body = body, Header = header, Control = control, Title = title, Description = desc }

	-- Lazily creates the full-width area under the header.
	function row.Extra(visible: boolean?)
		if not row._extra then
			row._extra = Create("Frame") {
				Name = "Extra",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Visible = visible ~= false,
				LayoutOrder = 2,
				Parent = body,
			}
		end
		return row._extra
	end

	return row
end

-- Hover/press state layer + ripple for a clickable surface.
-- opts.Header = the row (from Base.Row) of an element that opens content
-- below its header (a color picker): the layer and ripples then cover only
-- the header, and presses on the opened content don't light the row up.
-- Returns the state layer and a function telling whether an input is on
-- the pressable part.
function Base.Interactive(element, button: GuiButton, role: string?, opts)
	opts = opts or {}
	local theme = element._window.Theme
	local surface = button
	local header = opts.Header
	if header then
		-- A clipping frame over the header: holds the layer and the ripples.
		surface = Create("Frame") {
			Name = "Touch",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = button.ZIndex,
			Parent = button,
		}
		Shape.Corner(Shape.Medium, surface)
		local function fit()
			-- From the top of the row to just under the header (its padding).
			local height = header.Header.AbsolutePosition.Y + header.Header.AbsoluteSize.Y + 10 - button.AbsolutePosition.Y
			surface.Size = UDim2.new(1, 0, 0, math.max(height, 0))
		end
		fit()
		element._maid:GiveTask(button:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
		element._maid:GiveTask(header.Header:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
	end

	local function isPress(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	local function onSurface(input): boolean
		if surface == button then
			return true
		end
		local top = surface.AbsolutePosition.Y
		return input.Position.Y >= top and input.Position.Y <= top + surface.AbsoluteSize.Y
	end

	local layer = StateLayer.new(surface, theme.Colors[role or "OnSurface"], Shape.Medium)
	element._maid:GiveTask(layer)
	element._maid:GiveTask(theme.Changed:Connect(function()
		layer:SetColor(theme.Colors[role or "OnSurface"])
	end))
	-- On touch-only devices MouseEnter fires on a tap but MouseLeave often
	-- never does, which left the hover tint stuck; hover is for mice.
	local hoverable = not (UserInputService.TouchEnabled and not UserInputService.MouseEnabled)
	element._maid:GiveTask(button.MouseEnter:Connect(function()
		if hoverable then
			layer:SetState("Hover", true)
		end
	end))
	element._maid:GiveTask(button.MouseLeave:Connect(function()
		layer:SetState("Hover", false)
		layer:SetState("Pressed", false)
	end))
	element._maid:GiveTask(button.InputBegan:Connect(function(input)
		if isPress(input) and onSurface(input) then
			layer:SetState("Pressed", true)
			Ripple.Emit(surface, input.Position, theme.Colors[role or "OnSurface"])
		end
	end))
	element._maid:GiveTask(button.InputEnded:Connect(function(input)
		if isPress(input) then
			layer:SetState("Pressed", false)
		end
	end))
	return layer, onSurface
end

-- A small rounded input "field" used by Input / Dropdown / Slider value box.
function Base.Field(themer, className: string, parent: Instance, size: UDim2)
	local field = Create(className) {
		Name = "Field",
		BorderSizePixel = 0,
		Size = size,
		Text = "",
		Parent = parent,
	}
	if field:IsA("TextButton") then
		field.AutoButtonColor = false
	end
	Shape.Corner(Shape.Small, field)
	themer:Bind(field, { BackgroundColor3 = "SurfaceContainerHighest" })
	local stroke = Create("UIStroke") {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 1,
		Parent = field,
	}
	themer:Bind(stroke, { Color = "OutlineVariant" })
	return field, stroke
end

return Base
