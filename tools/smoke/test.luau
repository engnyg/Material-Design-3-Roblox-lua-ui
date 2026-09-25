-- Loaded by tools/smoke/run.py, which defines BUNDLE_SOURCE and the Roblox mock.

-- Fake executor environment (in-memory workspace folder). Defined before the
-- bundle loads because Env captures these globals at load time.
local files, folders = {}, {}
writefile = function(path, content) files[path] = content end
readfile = function(path) return files[path] or error(`no file {path}`) end
isfile = function(path) return files[path] ~= nil end
isfolder = function(path) return folders[path] == true end
makefolder = function(path) folders[path] = true end
delfile = function(path) files[path] = nil end
listfiles = function(folder)
	local out = {}
	for path in files do
		if path:sub(1, #folder + 1) == folder .. "/" and not path:sub(#folder + 2):find("/") then
			table.insert(out, path)
		end
	end
	return out
end
getcustomasset = function(path)
	assert(files[path], `getcustomasset: missing {path}`)
	return `rbxasset://custom/{path}`
end
local genv = {}
getgenv = function() return genv end
identifyexecutor = function() return "MockExecutor", "1.0" end
local httpRequests = {}
game.HttpGet = function(_, url)
	table.insert(httpRequests, url)
	if url:find("MaterialIconsSharp") then
		return "404: Not Found" -- exercises the fallback to Filled
	elseif url:find("MaterialIcons%a*%-Regular%.ttf") then
		return string.rep("x", 20000)
	elseif url:find("%.png") then
		return "\137PNG fake image bytes"
	elseif url:find("notfound") then
		return "<!DOCTYPE html><html>404</html>"
	end
	error(`unexpected HttpGet {url}`)
end

local chunk, loadErr = loadstring(BUNDLE_SOURCE, "=MaterialDesign3")
assert(chunk, loadErr)
-- Touching the chunk's environment turns off Luau's builtin fast paths, so
-- the bundle sees the mock's typeof() instead of the native one.
setfenv(chunk, getfenv())
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

-- Icons: Roblox BuilderIcons until a font is set (or plain characters with
-- BuilderIcons off), real Material codepoint after
local probe = Instance.new("TextLabel")
MD3.Icons.Apply(probe, "settings")
check(probe.Text == "gear" and probe.FontFace == MD3.Icons.BuilderFont, "BuilderIcons fallback wrong")
MD3.Icons.Apply(probe, "builder:sword")
check(probe.Text == "sword", "builder: prefix not honored")
MD3.Icons.SetBuilderIconsEnabled(false)
check(MD3.Icons.Glyph("check") == "\u{2713}", "Icons plain fallback glyph wrong")
check(not MD3.Icons.CanRender("settings"), "CanRender should be false without any icon font")
MD3.Icons.SetBuilderIconsEnabled(true)
MD3.Icons.SetFont(Font.new("rbxassetid://0"))
check(MD3.Icons.Glyph("check") == utf8.char(0xe5ca), "Icons codepoint wrong")

--== Executor layer ==--
local Env = MD3.Env
check(Env.IsExecutor and Env.Name == "MockExecutor", "Env did not detect the executor")
check(Env.CanUseFiles and Env.CanUseCustomAssets, "Env did not detect file functions")
Env.MakeFolder("A/B/C")
check(isfolder("A") and isfolder("A/B") and isfolder("A/B/C"), "Env.MakeFolder is not recursive")
check(Env.GetGuiParent() == game:GetService("Players").LocalPlayer.PlayerGui, "Env.GetGuiParent fallback wrong")
check(#Env.RandomName() == 12, "Env.RandomName length")

local font = MD3.IconFont.Load("MD3")
check(font ~= nil and files["MD3/MaterialIconsOutlined-Regular.ttf"] ~= nil, "IconFont should default to Outlined")
check(httpRequests[#httpRequests]:find("engnyg/Material%-Design%-3%-Roblox%-lua%-ui/main/assets/fonts/") ~= nil, "Outlined font should come from this repo")
check(MD3.Icons.GetFont() == font, "IconFont.Load did not set the icon font")
local round = MD3.IconFont.Load("MD3", "Round")
check(round ~= nil and round ~= font and files["MD3/MaterialIconsRound-Regular.ttf"] ~= nil, "IconFont Round style")
local sharp = MD3.IconFont.Load("MD3", "Sharp")
check(sharp ~= nil and files["MD3/MaterialIcons-Regular.ttf"] ~= nil and files["MD3/MaterialIconsSharp-Regular.ttf"] == nil, "IconFont did not fall back to Filled")
check(select(2, MD3.IconFont.Load("MD3", "Nope")) ~= nil, "unknown icon style should report an error")
-- Switching styles redraws icons that already exist
local existing = Instance.new("TextLabel")
existing.Parent = screen
MD3.Icons.Apply(existing, "settings")
check(existing.FontFace == MD3.Icons.GetFont() and existing.Text == utf8.char(0xe8b8), "icon not drawn with the current style")
MD3.IconFont.Load("MD3", "Round")
check(existing.FontFace == round and MD3.IconFont.CurrentStyle == "Round", "existing icon did not follow the style switch")
MD3.IconFont.Load("MD3", "Outlined")
check(existing.FontFace == font and MD3.IconFont.CurrentStyle == "Outlined", "existing icon did not follow the second switch")
-- With no icon font at all, it falls back to its own font (not a stale icon font)
local ownFont = MD3.Typography.Scale.BodyMedium.font
local plain = Instance.new("TextLabel")
plain.FontFace = ownFont
plain.Parent = screen
MD3.Icons.Apply(plain, "check")
MD3.Icons.SetBuilderIconsEnabled(false)
MD3.Icons.SetFont(nil)
check(plain.Text == "\u{2713}" and plain.FontFace == ownFont, "plain fallback did not restore the label's own font")
MD3.IconFont.Load("MD3", "Outlined")
MD3.Icons.SetBuilderIconsEnabled(true)
check(existing.FontFace == font, "existing icon did not return to the Material font")

-- External images: HttpGet -> writefile -> getcustomasset (cached)
local Assets = MD3.Assets
local logoUrl = "https://raw.githubusercontent.com/someone/repo/main/assets/logo.png?raw=true"
local logo = Assets.Resolve(logoUrl)
check(logo:match("^rbxasset://custom/MD3/assets/%x+_logo%.png$") ~= nil, `Assets.Resolve(url) gave {logo}`)
local requestsBefore = #httpRequests
check(Assets.Resolve(logoUrl) == logo and #httpRequests == requestsBefore, "Assets did not cache the download")
check(Assets.Resolve(123) == "rbxassetid://123" and Assets.Resolve("456") == "rbxassetid://456", "Assets numeric ids")
check(Assets.Resolve("rbxassetid://7") == "rbxassetid://7", "Assets should pass rbxassetid through")
check(Assets.Resolve("https://example.com/notfound") == "", "Assets accepted an HTML error page")
writefile("MyHub/icon.png", "bytes")
check(Assets.Resolve("MyHub/icon.png") == "rbxasset://custom/MyHub/icon.png", "Assets workspace file")
check(Assets.IsImage(logoUrl) and not Assets.IsImage("settings"), "Assets.IsImage")
local imageButton = MD3.IconButton.new({ Icon = logoUrl, Parent = screen })
check(imageButton._icon.Image == logo, "component Icon prop did not resolve the URL")

local host = Instance.new("ScreenGui")
local loadedCallbacks = {}
local function record(name)
	return function(...)
		loadedCallbacks[name] = table.pack(...)
	end
end

local Window = MD3:CreateWindow({
	Title = "Smoke Hub",
	Subtitle = "test",
	Icon = "widgets",
	Logo = logoUrl,
	Parent = host,
	MobileButton = true,
	ConfigFolder = "SmokeHub",
})
check(Window.Gui.Parent == host, "Window did not parent its ScreenGui")
check(Window.Theme.Mode == "Dark", "Window should default to dark mode")

local main = Window:AddTab({ Title = "Main", Icon = "home" })
check(Window.SelectedTab == main and main.Instance.Visible, "first tab not auto-selected")
local other = Window:CreateTab({ Title = "Other", Icon = logoUrl })
check(other._icon:IsA("ImageLabel") and other._icon.Image == logo, "Tab image icon not loaded")
local section = main:AddSection("Combat")

local clicks = 0
local button = section:AddButton({ Title = "Hit", Callback = function() clicks += 1 end })
button.Instance.Activated:Fire()
check(clicks == 1, "Button callback did not fire")

local toggle = section:AddToggle({ Title = "Auto", Flag = "Auto", Callback = record("toggle") })
toggle.Instance.Activated:Fire()
check(toggle.Value == true and loadedCallbacks.toggle[1] == true, "Toggle row click did not toggle")
toggle:Set(false)
check(toggle._switch:GetValue() == false, "Toggle:Set did not update the switch")

local slider = section:AddSlider({ Title = "Speed", Min = 16, Max = 100, Step = 0.5, Default = 20, Suffix = " ws", Flag = "Speed", Callback = record("slider") })
slider:Set(33.3)
check(slider.Value == 33.5 and loadedCallbacks.slider[1] == 33.5, "Slider did not snap to step")
slider:Set(1000)
check(slider.Value == 100, "Slider did not clamp")

local input = main:AddInput({ Title = "Name", Numeric = true, Flag = "Name", Callback = record("input") })
input:Set("12a3")
check(input.Value == "123", "Numeric Input did not filter")

local dropdown = main:AddDropdown({ Title = "Weapon", Options = { "Sword", "Bow" }, Default = "Sword", Flag = "Weapon", Callback = record("dropdown") })
dropdown:Set("Bow")
check(dropdown.Value == "Bow" and loadedCallbacks.dropdown[1] == "Bow", "Dropdown single select failed")
dropdown:SetOptions({ "Staff" })
check(dropdown.Value == nil, "Dropdown kept a removed option")

local multi = main:AddDropdown({ Title = "Targets", Options = { "A", "B", "C" }, Multi = true, Default = { "A" }, Flag = "Targets" })
multi:Set({ B = true, C = true })
table.sort(multi.Value)
check(#multi.Value == 2 and multi.Value[1] == "B", "Multi dropdown dictionary input failed")

local pressed = 0
local keybind = main:AddKeybind({ Title = "Dash", Default = "Q", Flag = "Dash", Callback = function() pressed += 1 end })
check(keybind.Value == Enum.KeyCode.Q, "Keybind string default not parsed")
local uis = game:GetService("UserInputService")
uis.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q }, false)
check(pressed == 1, "Keybind did not fire")
uis.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q }, true)
check(pressed == 1, "Keybind fired on a game-processed input")

local picker = other:AddColorPicker({ Title = "ESP", Default = Color3.fromRGB(255, 0, 0), Flag = "Esp", Callback = record("picker") })
picker:Set("#00ff00")
check(picker.Value:ToHex() == "00ff00", "ColorPicker hex input failed")

local label = other:AddLabel("hello")
label:Set("world")
check(label.Instance.Text == "world", "Label:Set failed")
other:AddParagraph({ Title = "About", Content = "text" })
other:AddDivider()

-- Toggle key hides/shows the window
uis.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.RightShift }, false)
check(Window.Visible == false and Window.Instance.Visible == false, "toggle key did not hide the window")
Window:Toggle()
check(Window.Visible == true, "Window:Toggle did not show the window")
Window:Minimize()
check(Window.Minimized, "Window did not minimize")
Window:Minimize(false)

Window:Notify({ Title = "Hi", Content = "there", Duration = 1 })
Window:Notify({ Title = "Img", Image = logoUrl, Duration = 1 })
local dialog = Window:Dialog({ Title = "Q", Content = "?", Buttons = { { Title = "OK", Callback = record("dialog") } } })
check(dialog.Instance.Visible, "Window:Dialog did not show")

-- Configs round-trip through the fake file system
local settings = Window:AddSettingsTab()
check(Window.Flags.MD3_DarkMode and Window.Flags.MD3_ToggleKey, "settings tab flags missing")
local styleDropdown = Window.Flags.MD3_IconStyle
check(styleDropdown and styleDropdown.Value == "Outlined", "settings tab icon style dropdown missing")
local navIcon = main._icon
styleDropdown:Set("Round")
check(MD3.IconFont.CurrentStyle == "Round" and navIcon.FontFace == round, "settings dropdown did not switch the icon style live")
styleDropdown:Set("Sharp")
check(MD3.IconFont.CurrentStyle == "Filled" and styleDropdown.Value == "Filled", "failed style switch should show the fallback")
styleDropdown:Set("Outlined")
check(Window:SaveConfig("main"), "SaveConfig failed")
check(table.find(Window:ListConfigs(), "main"), "ListConfigs missing saved config")
toggle:Set(true)
slider:Set(50)
dropdown:SetOptions({ "Sword", "Bow" })
multi:Set({})
keybind:Set(Enum.KeyCode.E)
picker:Set(Color3.new(0, 0, 1))
check(Window:LoadConfig("main"), "LoadConfig failed")
check(toggle.Value == false and slider.Value == 100, "config did not restore toggle/slider")
check(#multi.Value == 2 and keybind.Value == Enum.KeyCode.Q, "config did not restore multi/keybind")
check(picker.Value:ToHex() == "00ff00", "config did not restore color")
Window:SetAutoLoad("main")
check(Window:GetAutoLoad() == "main" and Window:LoadAutoloadConfig(), "autoload failed")
settings:Select()
check(Window.SelectedTab == settings, "Tab:Select failed")

-- Theme switch with the whole window alive
Window.Theme:Toggle()
Window.Theme:SetSeedColor(Color3.fromHex("#B3261E"))

-- Re-running the script replaces the old window
local unloaded = false
Window.OnUnload:Connect(function() unloaded = true end)
local second = MD3.CreateWindow({ Title = "Smoke Hub", Parent = host })
check(unloaded and Window._destroyed, "re-created window did not replace the old one")
second:Destroy()
check(second.Gui.Parent == nil, "Window:Destroy left the ScreenGui behind")

print(`smoke test passed ({checks} checks)`)
