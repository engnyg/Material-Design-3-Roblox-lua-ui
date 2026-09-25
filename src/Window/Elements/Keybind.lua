--[[
	Tab:AddKeybind({
		Title = "Dash",
		Default = Enum.KeyCode.Q,   -- or "Q"
		Mode = "Press",             -- "Press": Callback()  | "Toggle": Callback(on) | "Hold": Callback(isDown)
		Flag = "DashKey",
		Callback = function(...) end,
		ChangedCallback = function(newKey) end, -- when the user rebinds
		Notify = nil,               -- toast when used; default: on for Press / Toggle, off for Hold
	})

	Click the chip, then press a key. Esc cancels, Backspace unbinds.
	Keybinds don't fire while typing in a TextBox.
]]
local UserInputService = game:GetService("UserInputService")

local Root = script.Parent.Parent.Parent
local Base = require(script.Parent.Base)
local Create = require(Root.Util.Create)
local Typography = require(Root.Core.Typography)
local Shape = require(Root.Core.Shape)

local function toKeyCode(value)
	if typeof(value) == "EnumItem" then
		return value.EnumType == Enum.KeyCode and value ~= Enum.KeyCode.Unknown and value or nil
	elseif type(value) == "string" and value ~= "" and value ~= "None" then
		local ok, key = pcall(function()
			return (Enum.KeyCode :: any)[value]
		end)
		return ok and key or nil
	end
	return nil
end

return function(container, props)
	local element = Base.Element(container, props, "Keybind")
	local window = element._window
	local themer = window._themer
	local mode = props.Mode or "Press"
	local changedCallback = props.ChangedCallback
	local listening = false

	element.Value = toKeyCode(props.Default or props.Value or props.CurrentKeybind)
	element.State = false -- Toggle mode: current on/off, Hold mode: held down
	element.Mode = mode

	table.insert(window._keybinds, element)
	element._maid:GiveTask(function()
		local index = table.find(window._keybinds, element)
		if index then
			table.remove(window._keybinds, index)
		end
		window.KeybindsChanged:Fire()
	end)

	local function setState(state: boolean)
		element.State = state
		window.KeybindsChanged:Fire()
	end

	-- Toggle mode: set the on/off state from code (e.g. to match a Toggle
	-- element), without firing Callback.
	function element:SetState(state: boolean)
		setState(state == true)
	end

	local row = Base.Row(element, props, { ControlWidth = 96, ControlHeight = 32 })

	local chip = Create("TextButton") {
		Name = "Key",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.new(0, 0, 0, 32),
		AutomaticSize = Enum.AutomaticSize.X,
		BorderSizePixel = 0,
		Parent = row.Control,
		[1] = Create("UIPadding") { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) },
		[2] = Create("UISizeConstraint") { MinSize = Vector2.new(56, 32) },
	}
	Shape.Corner(Shape.Small, chip)
	Typography.Apply(chip, "LabelLarge")

	local function paint()
		chip.Text = listening and "..." or (element.Value and element.Value.Name or "None")
		themer:Bind(chip, {
			BackgroundColor3 = listening and "PrimaryContainer" or "SecondaryContainer",
			TextColor3 = listening and "OnPrimaryContainer" or "OnSecondaryContainer",
		})
	end

	element._normalize = toKeyCode
	element._render = paint
	-- A keybind's "value changed" is a rebind, so Set() reports through
	-- ChangedCallback; Callback is reserved for the key actually being used.
	function element:_emit(key)
		window.KeybindsChanged:Fire()
		self.Changed:Fire(key)
		if changedCallback then
			window:_call(changedCallback, key)
		end
	end

	function element:SetChangedCallback(fn)
		changedCallback = fn
	end

	local function fire(...)
		if element._callback then
			window:_call(element._callback, ...)
		end
	end

	-- Toast telling the player what the key just did. Hold keys stay quiet
	-- by default (you see the effect while holding). A new toast replaces
	-- this keybind's previous one, so repeated presses don't pile up.
	local notify = props.Notify
	if notify == nil then
		notify = mode ~= "Hold"
	end
	local toast = nil
	local function announce(content: string, icon: string)
		if not notify or not window:GetKeybindNotify() then
			return
		end
		if toast then
			toast.Close()
		end
		local title = element._title and element._title.Text or "Keybind"
		toast = window:Notify({ Title = title, Content = `{content} ({element.Value.Name})`, Icon = icon, Duration = 2 })
	end

	function element:SetNotify(enabled: boolean)
		notify = enabled
	end

	local function setListening(value: boolean)
		listening = value
		window._keybindListening = value
		paint()
	end

	element._maid:GiveTask(chip.Activated:Connect(function()
		setListening(not listening)
	end))

	element._maid:GiveTask(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if listening then
			if input.UserInputType ~= Enum.UserInputType.Keyboard then
				return
			end
			-- Marks this input as consumed so the window toggle and other
			-- keybinds (whose handlers may run after this one) ignore it.
			window._capturedKey = input.KeyCode
			window._capturedAt = os.clock()
			setListening(false)
			if input.KeyCode == Enum.KeyCode.Escape then
				paint()
			elseif input.KeyCode == Enum.KeyCode.Backspace then
				element:Set(nil)
			else
				element:Set(input.KeyCode)
			end
			return
		end

		if gameProcessed or UserInputService:GetFocusedTextBox() or window:_isCapturingKey(input) then
			return
		end
		if element.Value and input.KeyCode == element.Value then
			if mode == "Toggle" then
				setState(not element.State)
				fire(element.State)
				announce(if element.State then "Enabled" else "Disabled", if element.State then "toggle_on" else "toggle_off")
			elseif mode == "Hold" then
				setState(true)
				fire(true)
				announce("Holding", "keyboard")
			else
				fire()
				announce("Activated", "keyboard")
			end
		end
	end))

	if mode == "Hold" then
		element._maid:GiveTask(UserInputService.InputEnded:Connect(function(input)
			if element.State and element.Value and input.KeyCode == element.Value then
				setState(false)
				fire(false)
			end
		end))
	end

	paint()
	window.KeybindsChanged:Fire()
	return Base.Finish(element)
end
