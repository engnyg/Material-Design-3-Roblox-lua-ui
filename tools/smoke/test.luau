-- Loaded by tools/smoke/run.py, which defines BUNDLE_SOURCE and the Roblox mock.
local chunk, loadErr = loadstring(BUNDLE_SOURCE, "=MaterialDesign3")
assert(chunk, loadErr)
local MD3 = chunk()

local checks = 0
local function check(cond, msg)
	checks += 1
	assert(cond, msg)
end

for _, name in {
	"Theme", "Typography", "Shape", "Motion", "Elevation", "StateLayer", "Ripple", "Icons",
	"Color", "Signal", "Maid", "Create",
	"Button", "IconButton", "FAB", "Card", "Switch", "Checkbox", "RadioButton", "Slider",
	"TextField", "Chip", "Dialog", "Snackbar", "TopAppBar", "NavigationBar",
	"ProgressIndicator", "Divider",
} do
	check(MD3[name] ~= nil, `MD3.{name} missing from bundle`)
end

local screen = Instance.new("ScreenGui")
local click = { UserInputType = Enum.UserInputType.MouseButton1, Position = Vector2.new(10, 10) }

local function poke(inst)
	inst.MouseEnter:Fire()
	inst.InputBegan:Fire(click)
	inst.InputEnded:Fire(click)
	inst.Activated:Fire()
	inst.MouseLeave:Fire()
end

-- Button: every variant, disabled, activation reaches the public signal
local activated = 0
local button = MD3.Button.new({ Text = "Go", Parent = screen })
button.Activated:Connect(function() activated += 1 end)
poke(button.Instance)
check(activated == 1, "Button.Activated did not fire")
for _, variant in { "Filled", "Tonal", "Outlined", "Text", "Elevated" } do
	button:SetVariant(variant)
end
button:SetDisabled(true)
button.Instance.Activated:Fire()
check(activated == 1, "disabled Button still fired Activated")
button:Destroy()

local iconButton = MD3.IconButton.new({ Toggleable = true, Parent = screen })
poke(iconButton.Instance)
check(iconButton:GetSelected() == true, "IconButton toggle failed")

local fab = MD3.FAB.new({ Extended = true, Text = "New", Parent = screen })
poke(fab.Instance)

local card = MD3.Card.new({ Interactive = true, Parent = screen })
poke(card.Instance)

local switch = MD3.Switch.new({ Parent = screen })
poke(switch.Instance)
check(switch:GetValue() == true, "Switch did not toggle")

local checkbox = MD3.Checkbox.new({ Parent = screen })
poke(checkbox.Instance)
check(checkbox:GetValue() == true, "Checkbox did not toggle")
checkbox:SetValue("Indeterminate")
check(checkbox._mark.Text == MD3.Icons.Glyph("remove"), "Checkbox indeterminate glyph wrong")

local group = MD3.RadioButton.Group({ { Value = "a", Text = "A" }, { Value = "b", Text = "B" } }, "a", screen)
group:SetValue("b")
check(group.Value == "b", "RadioButton.Group SetValue failed")

local slider = MD3.Slider.new({ Min = 0, Max = 10, Step = 1, Value = 3, Parent = screen })
slider:SetValue(42)
check(slider:GetValue() == 10, "Slider did not clamp")

local field = MD3.TextField.new({ Label = "Name", Variant = "Filled", Parent = screen })
field._textBox.Focused:Fire()
field:SetText("hello")
field._textBox.FocusLost:Fire(true)
field:SetError(true, "Required")
check(field:GetText() == "hello", "TextField text lost")

local chip = MD3.Chip.new({ Text = "Tag", Variant = "Filter", Removable = true, Parent = screen })
poke(chip.Instance)

local dialog = MD3.Dialog.new({ Parent = screen, Title = "T", Text = "B", Actions = { { Text = "OK" } } })
local dismissed = false
dialog.Dismissed:Connect(function() dismissed = true end)
dialog:Show()
check(dialog.Instance.Visible == true, "Dialog did not show")
dialog:Hide()
flushTweens()
check(dialog.Instance.Visible == false and dismissed, "Dialog did not hide")

local snackbar = MD3.Snackbar.new({ Parent = screen })
snackbar:Show("Saved", { Text = "Undo" })

MD3.TopAppBar.new({ Title = "App", NavigationIcon = "", Actions = { { Icon = "" } }, Parent = screen })

local nav = MD3.NavigationBar.new({ Destinations = { { Label = "A" }, { Label = "B" } }, Parent = screen })
nav:SetSelected(2)
check(nav:GetSelected() == 2, "NavigationBar selection failed")

MD3.ProgressIndicator.Linear({ Value = 0.5, Parent = screen }):SetValue(1)
MD3.ProgressIndicator.Linear({ Indeterminate = true, Parent = screen })
local ring = MD3.ProgressIndicator.Circular({ Value = 0, Parent = screen })
for _, v in { 0, 0.001, 0.25, 0.5, 0.999, 1 } do
	ring:SetValue(v)
end
MD3.ProgressIndicator.Circular({ Indeterminate = true, Parent = screen })

MD3.Divider.new({ Parent = screen })

-- Live theming with everything above still alive
local theme = MD3.Theme.Default()
theme:Toggle()
check(theme.Mode == "Dark", "Theme did not toggle")
theme:SetSeedColor(Color3.fromHex("#006C51"))
theme:Toggle()

-- Icons: plain fallback until a font is set, real Material codepoint after
check(MD3.Icons.Glyph("check") == "\u{2713}", "Icons fallback glyph wrong")
MD3.Icons.SetFont(Font.new("rbxassetid://0"))
check(MD3.Icons.Glyph("check") == utf8.char(0xe5ca), "Icons codepoint wrong")

print(`smoke test passed ({checks} checks)`)
