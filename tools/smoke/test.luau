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

-- Most tests want the window on screen right away; the loading-screen tests
-- near the end pass LoadingScreen explicitly.
local createWindow = MD3.CreateWindow
MD3.CreateWindow = function(selfOrProps, maybeProps)
	local props = table.clone((if selfOrProps == MD3 then maybeProps else selfOrProps) or {})
	if props.LoadingScreen == nil then
		props.LoadingScreen = false
	end
	return createWindow(props)
end

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

-- Without any icon source, Material names draw nothing rather than a bare
-- Private Use Area character (which Windows renders as e.g. Chinese text)
MD3.Icons.SetFont(nil)
MD3.Icons.SetBuilderIconsEnabled(false)
check(MD3.Icons.Glyph("settings") == "" and not MD3.Icons.CanRender("settings"), "bare PUA codepoint emitted without a font")
MD3.Icons.SetBuilderIconsEnabled(true)
MD3.IconFont.Load("MD3", "Outlined")

-- Icon images (sprite sheets) loaded NeverLose-style, taking priority over the font
local IconImages = MD3.IconImages
local sheetLabel = Instance.new("TextLabel")
sheetLabel.TextSize = 20
sheetLabel.Parent = screen
MD3.Icons.Apply(sheetLabel, "home", true)
check(IconImages.Load("Filled") == true and IconImages.CurrentStyle == "Filled", "IconImages.Load failed")
check(files["MD3/assets/MaterialIconsFilled.png"] ~= nil, "icon sheet not saved to the workspace")
local sheetSprite = sheetLabel:FindFirstChild("MD3Icon")
check(sheetSprite and sheetSprite.Visible and sheetLabel.Text == "", "existing icon did not switch to the sprite sheet")
check(sheetSprite.Image == "rbxasset://custom/MD3/assets/MaterialIconsFilled.png", `sprite image wrong: {sheetSprite.Image}`)
local homeIndex = MD3.IconSheet.Index.home
check(sheetSprite.ImageRectOffset.X == (homeIndex % 12) * 72 + 4 and sheetSprite.ImageRectOffset.Y == math.floor(homeIndex / 12) * 72 + 4, "sprite cell offset wrong")
sheetLabel.TextColor3 = Color3.new(1, 0, 0)
check(sheetSprite.ImageColor3 == Color3.new(1, 0, 0), "sprite did not follow the label color")
check(IconImages.Load("Sharp") == false and IconImages.CurrentStyle == "Filled", "a broken sheet download should keep the previous style")
check(files["MD3/assets/MaterialIconsSharp.png"] == nil, "a non-PNG download was left on disk")
MOCK_ASSET_STATUS = Enum.AssetFetchStatus.Failure
check(IconImages.Load("Round") == false and IconImages.CurrentStyle == "Filled", "an image Roblox can't load should be rejected")
MOCK_ASSET_STATUS = nil
check(select(2, IconImages.Load("Nope")) ~= nil, "unknown sheet style should report an error")
IconImages.Unload()
check(not sheetSprite.Visible and sheetLabel.Text ~= "", "Unload did not return to glyphs")

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
check(IconImages.CurrentStyle == "Outlined", "Window should load the Outlined icon images")
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
local navSprite = main._icon:FindFirstChild("MD3Icon")
check(navSprite and navSprite.Image:find("MaterialIconsOutlined") ~= nil, "tab icon not drawn from the Outlined sheet")
styleDropdown:Set("Round")
check(IconImages.CurrentStyle == "Round" and navSprite.Image:find("MaterialIconsRound") ~= nil, "settings dropdown did not switch the icon style live")
styleDropdown:Set("Sharp")
check(IconImages.CurrentStyle == "Round" and styleDropdown.Value == "Round", "failed style switch should keep showing the previous style")
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

--== Theme overrides + theme editor ==--
local wt = Window.Theme
local red, green = Color3.new(1, 0, 0), Color3.new(0, 1, 0)
local generatedPrimary = wt.Colors.Primary
wt:SetOverride("Primary", red)
check(wt.Colors.Primary == red and wt:IsOverridden("Primary"), "SetOverride did not pin Primary")
check(wt.Colors.IconAccent == red, "IconAccent should follow an overridden Primary")
check(wt.Colors.OnPrimary == wt:ContrastColor(red), "OnPrimary should be recomputed for contrast")
wt:SetSeedColor(Color3.fromHex("#006A6A"))
check(wt.Colors.Primary == red, "override lost on SetSeedColor")
wt:SetMode(if wt.Mode == "Dark" then "Light" else "Dark")
check(wt.Colors.Primary == red, "override lost on SetMode")

-- IconColor + icon roles
local iconButton = main:AddButton({ Title = "Danger", Icon = "delete", IconColor = "Error" })
local iconLabel = iconButton.Instance:FindFirstChild("Body").Header.Control.Icon
check(iconLabel.TextColor3 == wt.Colors.Error, "Button IconColor role not applied")
local fixedTab = Window:AddTab({ Title = "Fixed", Icon = "bolt", IconColor = green })
check(fixedTab._icon.TextColor3 == green, "Tab IconColor Color3 not applied")
local plainButton = main:AddButton({ Title = "Plain", Icon = "home" })
local plainIcon = plainButton.Instance:FindFirstChild("Body").Header.Control.Icon
wt:SetOverride("Icon", green)
check(plainIcon.TextColor3 == green, "Icon role override did not recolor icons")
check(main._icon.TextColor3 == green or Window.SelectedTab == main, "unselected tab icon should use the Icon role")

-- Editor pickers stay in sync and edit overrides
local editorFlag = Window.Flags.MD3_ThemeOverrides
check(editorFlag and editorFlag.Value.Colors.Primary == red and editorFlag.Value.Colors.Icon == green, "MD3_ThemeOverrides flag not tracking overrides")
check(Window:SaveConfig("themed"), "SaveConfig with overrides failed")
wt:ClearOverrides()
check(wt.Colors.Primary ~= red and not wt:IsOverridden("Icon"), "ClearOverrides failed")
check(Window:LoadConfig("themed") and wt.Colors.Primary == red and wt.Colors.Icon == green, "config did not restore theme overrides")

local exported = wt:Export()
check(exported.Overrides.Primary == "ff0000" and exported.Mode == wt.Mode, "Theme:Export wrong")
wt:ClearOverrides()
wt:Import(exported)
check(wt.Colors.Primary == red, "Theme:Import did not restore overrides")
wt:Import({ Seed = "B3261E", Mode = "Light", Overrides = {} })
check(wt.Mode == "Light" and wt.Seed:ToHex() == "b3261e" and not wt:IsOverridden("Primary"), "Theme:Import seed/mode wrong")
check(Window.Flags.MD3_DarkMode.Value == false and Window.Flags.MD3_Accent.Value == wt.Seed, "settings toggles not synced after import")
check(generatedPrimary ~= nil, "sanity")

-- The editor UI itself (Settings > Theme editor)
local editor = nil
for _, section in settings._sections do
	if section._header and section._header.Text == "Theme editor" then
		editor = section
	end
end
check(editor ~= nil, "settings tab has no theme editor section")
local function find(title)
	for _, element in editor._elements do
		if element._title and element._title.Text == title then
			return element
		end
	end
	error(`theme editor has no "{title}"`)
end
find("Preset"):Set("Blue")
check(wt.Seed:ToHex() == "0061a4" and Window.Flags.MD3_Accent.Value:ToHex() == "0061a4", "preset did not apply")
local surfacePicker = find("Background")
check(surfacePicker.Value == wt.Colors.Surface and surfacePicker._desc.Text == "Surface", "picker not showing the current color")
surfacePicker:Set(Color3.fromHex("#112233"))
check(wt.Colors.Surface:ToHex() == "112233" and surfacePicker._desc.Text == "Surface · custom", "picker edit did not override the role")
check(wt.Colors.OnSurface == wt:ContrastColor(wt.Colors.Surface), "text color not adjusted for the custom background")
find("Reset custom colors"):Fire()
check(not wt:IsOverridden("Surface") and surfacePicker.Value == wt.Colors.Surface, "reset did not refresh pickers")
wt:SetOverride("Tertiary", red)
local json = game:GetService("HttpService"):JSONEncode(wt:Export())
wt:ClearOverrides()
find("Import theme"):Set(json)
check(wt.Colors.Tertiary == red, "import input did not apply the theme")
wt:ClearOverrides()

--== Theme / icon / text color (one control each) ==--
local white = Color3.new(1, 1, 1)
wt:SetTextColor(white)
check(wt.Colors.OnSurface == white and wt.Colors.OnBackground == white, "SetTextColor did not set the text color")
check(wt.Colors.OnSurfaceVariant == MD3.Color.Blend(white, wt.Colors.Surface, 0.3), "secondary text should follow the text color")
check(wt.Colors.Icon == wt.Colors.OnSurfaceVariant, "icons should follow the text color by default")
wt:SetIconColor(green)
check(wt.Colors.Icon == green and wt.Colors.IconAccent == green and wt.Colors.IconSelected == green, "SetIconColor should recolor every icon")
wt:SetOverride("IconAccent", red)
check(wt.Colors.IconAccent == red and wt.Colors.Icon == green, "a specific icon role override should win")
wt:ClearOverrides()

local appearance = settings._sections[1]
local function findIn(section, title)
	for _, element in section._elements do
		if element._title and element._title.Text == title then
			return element
		end
	end
	error(`no "{title}" in {section._header.Text}`)
end
check(findIn(appearance, "Theme color") == Window.Flags.MD3_Accent, "Theme color picker missing")
local iconPicker, textPicker = findIn(appearance, "Icon color"), findIn(appearance, "Text color")
check(iconPicker.Value == wt.Colors.Icon and textPicker.Value == wt.Colors.OnSurface, "quick pickers not showing current colors")
iconPicker:Set(green)
textPicker:Set(white)
check(wt.Colors.Icon == green and wt.Colors.OnSurface == white, "quick pickers did not recolor")
check(iconPicker._desc.Text == "Custom" and textPicker._desc.Text == "Custom", "quick pickers not marked custom")
check(plainIcon.TextColor3 == green, "existing icons did not follow the icon color")
findIn(appearance, "Reset icon & text colors"):Fire()
check(not wt:IsOverridden("Icon") and not wt:IsOverridden("OnSurface") and textPicker.Value == wt.Colors.OnSurface, "reset icon & text colors failed")

--== Transparency ==--
-- Color picker opacity bar
local alphaPicker = other:AddColorPicker({ Title = "Alpha", Default = red, Transparency = 0.25, Flag = "AlphaColor", Callback = record("alpha") })
check(alphaPicker.Transparency == 0.25, "ColorPicker Transparency default")
alphaPicker:SetTransparency(0.5)
check(loadedCallbacks.alpha[1] == red and loadedCallbacks.alpha[2] == 0.5, "ColorPicker callback should get (color, transparency)")
check(Window:SaveConfig("alpha"), "SaveConfig with transparency failed")
alphaPicker:Set({ Color = green, Transparency = 0.1 })
check(alphaPicker.Value == green and alphaPicker.Transparency == 0.1, "ColorPicker table Set")
check(Window:LoadConfig("alpha") and alphaPicker.Value == red and alphaPicker.Transparency == 0.5, "config did not restore color + transparency")
local plainPicker = other:AddColorPicker({ Title = "No alpha", Default = red, Callback = record("noalpha") })
plainPicker:Set(green)
check(loadedCallbacks.noalpha.n == 1, "a picker without Transparency should keep the one-argument callback")

-- Theme role transparency reaches the window
wt:SetOverride("Surface", Color3.fromHex("#101018"), 0.4)
check(Window.Instance.BackgroundTransparency == 0.4, "Surface transparency not applied to the window background")
wt:SetTransparency("Surface", nil)
check(Window.Instance.BackgroundTransparency == 0, "removing the transparency should make the window opaque again")
wt:SetTransparency("SurfaceContainerHigh", 0.5)
check(plainButton.Instance.BackgroundTransparency == 0.5, "row transparency not applied")
wt:SetOverride("OnSurface", white, 0.2)
local rowTitle = plainButton.Instance:FindFirstChild("Body").Header:FindFirstChild("Text").Title
check(rowTitle.TextTransparency == 0.2 and plainIcon.TextTransparency == 0.2, "text transparency should reach text and (cascading) icons")
local plainSprite = plainIcon:FindFirstChild("MD3Icon")
check(plainSprite == nil or plainSprite.ImageTransparency == 0.2, "icon image should follow the icon transparency")
check(wt:Export().Transparency.OnSurface == 0.2, "Export should include transparency")
wt:ClearOverrides()
check(Window.Instance.BackgroundTransparency == 0 and plainButton.Instance.BackgroundTransparency == 0 and rowTitle.TextTransparency == 0, "ClearOverrides should restore opacity")

-- Theme editor pickers edit transparency and it's saved
surfacePicker:SetTransparency(0.3)
check(wt:GetTransparency("Surface") == 0.3 and Window.Flags.MD3_ThemeOverrides.Value.Transparency.Surface == 0.3, "editor opacity did not set the role transparency")
check(surfacePicker._desc.Text == "Surface · custom", "transparency-only change should mark the role custom")
check(Window:SaveConfig("see-through"), "SaveConfig see-through failed")
wt:ClearOverrides()
check(Window:LoadConfig("see-through") and wt:GetTransparency("Surface") == 0.3 and Window.Instance.BackgroundTransparency == 0.3, "config did not restore theme transparency")
wt:ClearOverrides()

--== Resizing ==--
local grip = Window._grip
local startSize = Window:GetSize()
local mouse = Enum.UserInputType.MouseButton1
grip.InputBegan:Fire({ UserInputType = mouse, Position = Vector2.new(100, 100) })
uis.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector2.new(200, 150) })
uis.InputEnded:Fire({ UserInputType = mouse, Position = Vector2.new(200, 150) })
local resized = Window:GetSize()
local scale = Window._uiScale.Scale
check(resized.X.Offset == math.round(startSize.X.Offset + 100 / scale) and resized.Y.Offset == math.round(startSize.Y.Offset + 50 / scale), `resize handle size wrong: {resized.X.Offset}x{resized.Y.Offset}`)
check(Window.Instance.Size == resized or (Window.Instance.Size.X.Offset == resized.X.Offset and Window.Instance.Size.Y.Offset == resized.Y.Offset), "window not resized")
check(files["SmokeHub/window.json"] ~= nil, "resized size not saved")
grip.InputBegan:Fire({ UserInputType = mouse, Position = Vector2.new(500, 500) })
uis.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector2.new(-2000, -2000) })
uis.InputEnded:Fire({ UserInputType = mouse, Position = Vector2.new(-2000, -2000) })
check(Window:GetSize().X.Offset == 420 and Window:GetSize().Y.Offset == 280, "resize should stop at the minimum size")
Window:SetSize(640, 400)
local restoredWindow = MD3.CreateWindow({ Title = "Restore", Parent = host, ConfigFolder = "SmokeHub" })
check(restoredWindow:GetSize().X.Offset == 640 and restoredWindow:GetSize().Y.Offset == 400, "a new window did not restore the saved size")
restoredWindow:ResetSize()
check(restoredWindow:GetSize().X.Offset == 600 and restoredWindow:GetSize().Y.Offset == 420, "ResetSize should return to the default size")
restoredWindow:Destroy()
local fixedWindow = MD3.CreateWindow({ Title = "Fixed size", Parent = host, ConfigFolder = "SmokeHub", RememberSize = false, Size = UDim2.fromOffset(500, 350) })
check(fixedWindow:GetSize().X.Offset == 500, "RememberSize = false should ignore the saved size")
fixedWindow:Destroy()
-- Minimize folds up into the title bar and restore unfolds downward: the top
-- edge (center minus half the scaled height) must not move, at any UIScale.
local function topEdge()
	local main = Window.Instance
	return main.Position.Y.Offset - main.Size.Y.Offset * Window._uiScale.Scale / 2
end
local savedScale = Window._uiScale.Scale
for _, uiScale in { 1, 0.8 } do
	Window._uiScale.Scale = uiScale
	local top, fullHeight = topEdge(), Window.Instance.Size.Y.Offset
	Window:Minimize(true)
	check(not grip.Visible, "resize handle should hide while minimized")
	check(Window.Instance.Size.Y.Offset < fullHeight, "Minimize did not shrink the window")
	check(math.abs(topEdge() - top) < 1e-6, `Minimize moved the top edge at scale {uiScale}`)
	Window:Minimize(false)
	check(Window.Instance.Size.Y.Offset == fullHeight, "restore did not return to full height")
	check(math.abs(topEdge() - top) < 1e-6, `restore did not expand downward at scale {uiScale}`)
end
Window._uiScale.Scale = savedScale

local colored = MD3.CreateWindow({ Title = "Colors", Parent = host, ThemeColor = Color3.fromHex("#006E1C"), TextColor = white, IconColor = red })
check(colored.Theme.Seed:ToHex() == "006e1c" and colored.Theme.Colors.OnSurface == white and colored.Theme.Colors.Icon == red, "CreateWindow ThemeColor/TextColor/IconColor")
colored:Destroy()

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

-- HUD: watermark, keybind list, indicators
local keyboard = Enum.UserInputType.Keyboard
local function press(key) uis.InputBegan:Fire({ UserInputType = keyboard, KeyCode = key }, false) end
local function release(key) uis.InputEnded:Fire({ UserInputType = keyboard, KeyCode = key }) end

local hudWindow = MD3.CreateWindow({ Title = "HUD Hub", Icon = "widgets", Parent = host })
local hudTab = hudWindow:AddTab({ Title = "Binds" })
local fly = hudTab:AddKeybind({ Title = "Fly", Default = "F", Mode = "Toggle" })
hudTab:AddKeybind({ Title = "Sprint", Default = "LeftShift", Mode = "Hold" })
local dashBind = hudTab:AddKeybind({ Title = "Dash", Default = "Q" })
hudTab:AddKeybind({ Title = "Unbound", Mode = "Toggle" })

local wm = hudWindow:AddWatermark({ FPS = true, Ping = true, Clock = true })
local layer = hudWindow._hudLayer
check(layer ~= nil and layer.Parent == hudWindow.Gui and wm.Instance.Parent == layer, "watermark is not on the HUD layer")
local blocks = wm._blocks
check(#blocks == 4 and wm.TitleBlock == blocks[1], "watermark should have title + FPS + ping + clock")
check(wm.TitleBlock:GetText() == "HUD Hub", "watermark title should default to the window title")
check(not blocks[1]._separator.Visible and blocks[2]._separator.Visible, "watermark separators wrong")
check(blocks[2]:GetText() == "-- FPS", "FPS should show -- before the first sample")
check(blocks[3]:GetText() == "45 ms", `ping block shows {blocks[3]:GetText()}`)
check(string.match(blocks[4]:GetText(), "^%d%d:%d%d:%d%d$") ~= nil, `clock block shows {blocks[4]:GetText()}`)
local heartbeat = game:GetService("RunService").Heartbeat
for _ = 1, 31 do -- 30 × 1/60 lands a hair under the 0.5 s window in floating point
	heartbeat:Fire(1 / 60)
end
check(blocks[2]:GetText() == "60 FPS", `FPS block shows {blocks[2]:GetText()}`)

local blockClicks = 0
local custom = wm:AddBlock("bolt", "Ready")
custom:OnClick(function() blockClicks += 1 end)
custom.Instance.InputBegan:Fire(click)
uis.InputEnded:Fire(click)
check(blockClicks == 1, "clicking a watermark block did not run its callback")
custom:SetText("Running")
check(custom:GetText() == "Running", "Block:SetText failed")
blocks[1]:SetVisible(false)
check(not blocks[2]._separator.Visible, "the first visible block should have no separator")
blocks[1]:SetVisible(true)
custom:Destroy()
check(#wm._blocks == 4 and custom.Instance.Parent == nil, "Block:Destroy did not remove the block")

local wmStart = wm.Instance.Position
wm.Instance.InputBegan:Fire(click)
uis.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseMovement, Position = Vector2.new(60, 40) })
uis.InputEnded:Fire(click)
check(wm.Instance.Position.X.Offset == wmStart.X.Offset + 50 and wm.Instance.Position.Y.Offset == wmStart.Y.Offset + 30, "watermark did not drag")

local list = hudWindow:AddKeybindList()
check(list.Count == 0 and not list.Instance.Visible, "an active-only keybind list should hide while nothing is on")
press(Enum.KeyCode.F)
check(fly.State and list.Count == 1 and list.Instance.Visible, "a toggled-on keybind is not listed")
local flyRow = list._rows:FindFirstChild("Fly")
check(flyRow ~= nil and flyRow.Key.Text == "F", "keybind row should show the key")
press(Enum.KeyCode.LeftShift)
check(list.Count == 2, "a held keybind is not listed")
release(Enum.KeyCode.LeftShift)
check(list.Count == 1, "a released hold keybind is still listed")
fly:Set(Enum.KeyCode.G)
check(list._rows:FindFirstChild("Fly").Key.Text == "G", "keybind list did not follow a rebind")
press(Enum.KeyCode.G)
check(not fly.State and list.Count == 0 and not list.Instance.Visible, "keybind list did not empty when toggled off")

local all = hudWindow:AddKeybindList({ ShowAll = true, Position = UDim2.fromOffset(300, 200) })
check(all.Count == 3 and all.Instance.Visible, `ShowAll should list the 3 bound keybinds, got {all.Count}`)
check(all.Instance.Position.X.Offset == 300 and all.Instance.AnchorPoint.X == 0, "UDim2 Position not applied")
dashBind:Destroy()
check(all.Count == 2, "a destroyed keybind is still listed")

local red = Color3.fromRGB(255, 80, 80)
local auto = hudWindow:AddIndicator({ Text = "AUTO", Icon = "bolt" })
local hc = hudWindow:AddIndicator({ Text = "HC", Color = red })
check(auto.Instance.Parent == hudWindow._hudIndicators and hc.Instance.LayoutOrder > auto.Instance.LayoutOrder, "indicators should stack in order")
check(auto._label.TextColor3 == hudWindow.Theme.Colors.Primary and hc._label.TextColor3 == red, "indicator colors wrong")
auto:SetColor("Error")
hudWindow.Theme:Toggle()
check(auto._label.TextColor3 == hudWindow.Theme.Colors.Error, "indicator color did not follow the theme")
auto:SetText("FL")
check(auto:GetText() == "FL", "Indicator:SetText failed")
auto:SetRender(false)
check(not auto.Instance.Visible, "Indicator:SetRender(false) did not hide it")

hudWindow:SetVisible(false)
check(layer.Visible and wm.Instance.Visible, "the HUD should stay up while the window is hidden")
hudWindow:SetVisible(true)
hudWindow:AddSettingsTab()
local showHud = hudWindow.Flags.MD3_ShowHUD
check(showHud ~= nil, "the settings tab should offer Show HUD once a HUD exists")
showHud:Set(false)
check(not layer.Visible, "Show HUD off did not hide the HUD")
showHud:Set(true)

-- HUD transparency is separate from the window's
local hudTheme = hudWindow.Theme
local wmStroke = wm.Instance:FindFirstChild("UIStroke")
local titleLabel = wm.TitleBlock._label
local hcLabel = hc._label
local function near(a, b)
	return type(a) == "number" and math.abs(a - b) < 1e-6
end
hudTheme:SetTransparency("SurfaceContainerHigh", 0.5) -- window rows
hudTheme:SetTransparency("OnSurface", 0.5) -- window text
hudTheme:SetTransparency("Primary", 0.5) -- the indicator's color role
check(near(wm.Instance.BackgroundTransparency, 0) and near(titleLabel.TextTransparency, 0) and near(hcLabel.TextTransparency, 0),
	"window transparency leaked into the HUD")
check(near(auto._label.TextTransparency, 0), "an indicator took its color role's transparency")

hudWindow:SetHUDTransparency(0.4, 0.2)
local bg, text = hudWindow:GetHUDTransparency()
check(near(bg, 0.4) and near(text, 0.2), "GetHUDTransparency wrong")
check(near(wm.Instance.BackgroundTransparency, 0.4) and near(wmStroke.Transparency, 0.4), "HUD background transparency not applied")
check(near(blocks[2]._separator.BackgroundTransparency, 0.4), "separators should follow the HUD background")
check(near(titleLabel.TextTransparency, 0.2) and near(hcLabel.TextTransparency, 0.2), "HUD text transparency not applied")
local titleIcon = wm.TitleBlock._icon
check(titleIcon ~= nil and near(if titleIcon:IsA("ImageLabel") then titleIcon.ImageTransparency else titleIcon.TextTransparency, 0.2), "HUD icons should follow the text transparency")
press(Enum.KeyCode.G) -- Fly on again, so the list has a row with a key chip
local chip = list._rows:FindFirstChild("Fly").Key
check(near(chip.BackgroundTransparency, 0.4) and near(chip.TextTransparency, 0.2), "keybind chips should follow the HUD transparency")
local windowRow = hudTab._elements[1].Instance
check(near(windowRow.BackgroundTransparency, 0.5), "HUD transparency leaked into the window")

auto:SetTransparency(0.9)
check(near(auto.Instance.BackgroundTransparency, 0.9) and near(auto._label.TextTransparency, 0.2), "per-piece background transparency")
check(near(hc.Instance.BackgroundTransparency, 0.4), "one indicator's transparency changed another")
auto:SetTransparency(nil, 0.7)
check(near(auto.Instance.BackgroundTransparency, 0.4) and near(auto._label.TextTransparency, 0.7), "per-piece text transparency")
hudTheme:Toggle()
check(near(auto._label.TextTransparency, 0.7) and near(wm.Instance.BackgroundTransparency, 0.4), "HUD transparency lost on theme change")
check(near(hudWindow.Flags.MD3_ThemeOverrides:Get().Transparency.HUDBackground, 0.4), "HUD transparency is not saved with the theme")

local function findElement(window, title)
	for _, tab in window.Tabs do
		for _, section in tab._sections do
			for _, element in section._elements do
				if element._title and element._title.Text == title then
					return element
				end
			end
		end
	end
	return nil
end
local bgSlider = findElement(hudWindow, "Background transparency")
local textSlider = findElement(hudWindow, "Text transparency")
check(bgSlider ~= nil and textSlider ~= nil, "settings tab should have HUD transparency sliders")
check(bgSlider.Value == 40 and textSlider.Value == 20, "HUD sliders did not follow SetHUDTransparency")
bgSlider:Set(75)
check(near(wm.Instance.BackgroundTransparency, 0.75) and near(titleLabel.TextTransparency, 0.2), "background slider did not set the HUD background")
check(near(windowRow.BackgroundTransparency, 0.5), "HUD slider changed the window")
hudWindow:SetHUDTransparency(0, 0)
check(bgSlider.Value == 0 and textSlider.Value == 0 and near(wm.Instance.BackgroundTransparency, 0), "HUD back to solid")

hudWindow:Destroy()
check(wm._destroyed and list._destroyed and all._destroyed and auto._destroyed, "HUD pieces not destroyed with the window")
for _ = 1, 30 do
	heartbeat:Fire(1 / 30)
end
check(wm.FPS == 60, "the watermark kept ticking after unload")

-- Loading screen
local loading = MD3.CreateWindow({ Title = "Loader Hub", Subtitle = "v2", Icon = "widgets", Parent = host, ConfigFolder = "LoaderHub", LoadingScreen = true })
local splash = loading._loadingScreen
check(splash ~= nil and splash.Instance.Parent == loading.Gui, "the loading screen was not shown")
check(not loading.IsLoaded and not loading.Instance.Visible, "the window should wait for the loading screen")
check(splash.Instance.Title.Text == "Loader Hub" and splash.Instance.Subtitle.Text == "v2", "loading screen should show the window title and subtitle")
local loadedFired = 0
loading.Loaded:Connect(function() loadedFired += 1 end)
local loadingTab = loading:AddTab({ Title = "Main" })
loadingTab:AddToggle({ Title = "Built while loading" })
check(#loading.Tabs == 1, "the script should keep building the window while it loads")

loading._iconsReady = false -- icon images still downloading
heartbeat:Fire(0.6)
local midway = splash.Progress
check(midway > 0 and midway < 0.7, `progress while waiting for icons: {midway}`)
heartbeat:Fire(1)
check(not splash.Finished and splash.Progress < 0.7, "the loading screen should wait for the icon images")
loading._iconsReady = true
heartbeat:Fire(0.1)
check(splash.Finished and splash.Progress == 1, "the loading screen did not finish once the icons were in")
check(not loading.Instance.Visible and loadedFired == 0, "the window should appear after the fade-out, not before")
flushTweens()
check(loading.IsLoaded and loadedFired == 1 and loading.Instance.Visible, "the window was not shown after loading")
check(splash.Instance.Parent == nil and loading._loadingScreen == nil, "the loading card was not removed")
heartbeat:Fire(1)
check(loadedFired == 1, "Loaded fired more than once")

-- Minimum time, and hiding the window while it loads
local hidden = MD3.CreateWindow({ Title = "Hidden Hub", Parent = host, ConfigFolder = "LoaderHub", LoadingScreen = { Title = "Custom", Duration = 3 } })
local hiddenSplash = hidden._loadingScreen
check(hiddenSplash.Instance.Title.Text == "Custom", "LoadingScreen.Title not used")
hidden:Toggle()
check(hidden.Visible == false and not hidden.Instance.Visible, "toggling during loading should only record the wish")
hidden:Toggle()
check(hidden.Visible == true and not hidden.Instance.Visible, "showing the window during loading should wait for the loading screen")
hidden:Toggle()
heartbeat:Fire(2)
check(not hiddenSplash.Finished, "LoadingScreen.Duration should keep it up for 3 s")
heartbeat:Fire(1.5)
flushTweens()
check(hidden.IsLoaded and not hidden.Instance.Visible, "a window hidden during loading should stay hidden")
hidden:Toggle()
check(hidden.Instance.Visible, "the window did not show after loading")
hidden:Destroy()

-- SkipLoading, and unloading mid-way
local skipped = MD3.CreateWindow({ Title = "Skip Hub", Parent = host, ConfigFolder = "LoaderHub", LoadingScreen = true })
skipped:SkipLoading()
flushTweens()
check(skipped.IsLoaded and skipped.Instance.Visible, "SkipLoading did not show the window")
skipped:Destroy()
local unloadedEarly = MD3.CreateWindow({ Title = "Early Hub", Parent = host, ConfigFolder = "LoaderHub", LoadingScreen = true })
local earlyCard = unloadedEarly._loadingScreen.Instance
unloadedEarly:Destroy()
heartbeat:Fire(5)
flushTweens()
check(earlyCard.Parent == nil and not unloadedEarly.IsLoaded, "unloading during the loading screen left it behind")

-- The player's on/off switch (saved for the next run)
loading:AddSettingsTab()
local loadingSwitch = findElement(loading, "Loading animation")
check(loadingSwitch ~= nil and loadingSwitch.Value == true, "the settings tab should have the loading animation switch, on")
loadingSwitch:Set(false)
check(files["LoaderHub/loading.txt"] == "off" and not loading:GetLoadingScreenEnabled(), "turning the switch off was not saved")
loading:Destroy()
local noSplash = MD3.CreateWindow({ Title = "Next Run", Parent = host, ConfigFolder = "LoaderHub", LoadingScreen = true })
check(noSplash._loadingScreen == nil and noSplash.IsLoaded and noSplash.Instance.Visible, "the saved off switch was ignored")
noSplash:SetLoadingScreenEnabled(true)
noSplash:Destroy()
local again = MD3.CreateWindow({ Title = "Run After", Parent = host, ConfigFolder = "LoaderHub", LoadingScreen = true })
check(again._loadingScreen ~= nil, "turning the switch back on was ignored")
again:Destroy()

-- LoadingScreen = false from the script: never shown, no switch in settings
local scriptOff = MD3.CreateWindow({ Title = "Script Off", Parent = host, ConfigFolder = "LoaderHub", LoadingScreen = false })
check(scriptOff._loadingScreen == nil and scriptOff.IsLoaded and not scriptOff:GetLoadingScreenEnabled(), "LoadingScreen = false was not respected")
scriptOff:AddSettingsTab()
check(findElement(scriptOff, "Loading animation") == nil, "no loading switch when the script turned it off")
scriptOff:Destroy()

-- Silent start: no loading screen, starts hidden, autoload without a toast
local silent = MD3.CreateWindow({ Title = "Silent Hub", Parent = host, ConfigFolder = "SilentHub", ToggleKey = "F8", Silent = true, LoadingScreen = true })
check(silent.Silent and silent._loadingScreen == nil and silent.IsLoaded, "Silent should skip the loading screen")
check(silent.Visible == false and not silent.Instance.Visible, "a silent window should start hidden")
local silentTab = silent:AddTab({ Title = "Main" })
local silentToggle = silentTab:AddToggle({ Title = "Auto", Flag = "SilentAuto" })
silentToggle:Set(true)
silent:SaveConfig("default")
silent:SetAutoLoad("default")
silentToggle:Set(false)
local function toasts(window)
	return #window._notifier.Instance:GetChildren() - 1 -- minus the UIListLayout
end
check(silent:LoadAutoloadConfig() and silentToggle.Value == true, "silent autoload did not apply the config")
check(toasts(silent) == 0, "silent autoload should not notify")
silent:Notify({ Title = "Explicit" })
check(toasts(silent) == 1, "an explicit Notify should still show in silent mode")
silent:AddSettingsTab()
check(findElement(silent, "Loading animation") == nil, "no loading switch in silent mode")
press(Enum.KeyCode.F8)
check(silent.Visible and silent.Instance.Visible, "the toggle key should open a silent window")
silentTab:AddKeybind({ Title = "Dash", Default = "F9" })
press(Enum.KeyCode.F9)
check(toasts(silent) == 1, "keybinds should not notify in silent mode")
silent:Destroy()
local loud = MD3.CreateWindow({ Title = "Loud Hub", Parent = host, ConfigFolder = "SilentHub" })
loud:AddTab({ Title = "Main" }):AddToggle({ Title = "Auto", Flag = "SilentAuto" })
check(loud.Instance.Visible and loud:LoadAutoloadConfig() and toasts(loud) == 1, "a normal window should notify on autoload")
loud:Destroy()

-- Keybind toasts: the player's own keybinds notify, the UI toggle key doesn't
local toastWin = MD3.CreateWindow({ Title = "Toast Hub", Parent = host, ToggleKey = "F7" })
local keysTab = toastWin:AddTab({ Title = "Keys" })
keysTab:AddKeybind({ Title = "Fly", Default = "F2", Mode = "Toggle" })
keysTab:AddKeybind({ Title = "Dash", Default = "F3" })
local holdKey = keysTab:AddKeybind({ Title = "Sprint", Default = "F4", Mode = "Hold" })
keysTab:AddKeybind({ Title = "Muted", Default = "F5", Notify = false })
toastWin:AddSettingsTab() -- has a "Toggle UI" keybind on F7 too
local function lastToast(window)
	local newest = nil
	for _, slot in window._notifier.Instance:GetChildren() do
		if slot.Name == "Notification" and (newest == nil or slot.LayoutOrder > newest.LayoutOrder) then
			newest = slot
		end
	end
	-- The card is a TextButton, so .Text is its Text property: look the column up by name.
	local column = newest.Card:FindFirstChild("Text")
	return column.Title.Text, column.Content.Text
end
press(Enum.KeyCode.F7)
check(not toastWin.Visible and toasts(toastWin) == 0, "the UI toggle key should not notify")
press(Enum.KeyCode.F7)
check(toastWin.Visible and toasts(toastWin) == 0, "the UI toggle key should not notify (showing)")
press(Enum.KeyCode.F2)
local title, content = lastToast(toastWin)
check(toasts(toastWin) == 1 and title == "Fly" and content == "Enabled (F2)", `toggle keybind toast: {title} / {content}`)
press(Enum.KeyCode.F2)
flushTweens()
title, content = lastToast(toastWin)
check(toasts(toastWin) == 1 and content == "Disabled (F2)", "a keybind's new toast should replace its previous one")
press(Enum.KeyCode.F3)
title, content = lastToast(toastWin)
check(toasts(toastWin) == 2 and title == "Dash" and content == "Activated (F3)", `press keybind toast: {title} / {content}`)
press(Enum.KeyCode.F4)
release(Enum.KeyCode.F4)
check(toasts(toastWin) == 2, "hold keybinds should stay quiet by default")
press(Enum.KeyCode.F5)
check(toasts(toastWin) == 2, "Notify = false should stay quiet")
toastWin:SetKeybindNotify(false)
press(Enum.KeyCode.F3)
flushTweens()
check(toasts(toastWin) == 2 and not toastWin:GetKeybindNotify(), "SetKeybindNotify(false) should silence every keybind")
toastWin:SetKeybindNotify(true)
holdKey:SetNotify(true)
press(Enum.KeyCode.F4)
release(Enum.KeyCode.F4)
title, content = lastToast(toastWin)
check(toasts(toastWin) == 3 and content == "Holding (F4)", "SetNotify(true) on a hold keybind")
toastWin:Destroy()
local quietKeys = MD3.CreateWindow({ Title = "Quiet Keys", Parent = host, KeybindNotify = false })
quietKeys:AddTab({ Title = "Keys" }):AddKeybind({ Title = "Dash", Default = "F10" })
press(Enum.KeyCode.F10)
check(toasts(quietKeys) == 0, "KeybindNotify = false should silence keybinds")
quietKeys:Destroy()

-- Custom background image
local bgWin = MD3.CreateWindow({ Title = "Background Hub", Parent = host, ConfigFolder = "BgHub", Background = logoUrl })
local bgImage = bgWin._background
local bgSource, bgTransparency = bgWin:GetBackground()
check(bgSource == logoUrl and bgImage.Visible and bgImage.Image ~= "", "CreateWindow Background was not loaded")
check(near(bgTransparency, 0.4) and near(bgImage.ImageTransparency, 0.4), "default background transparency should be 0.4")
check(bgImage.Parent == bgWin.Instance and bgImage.ZIndex < bgWin.Instance.TopBar.ZIndex, "the background should sit behind the window content")
check(bgImage:FindFirstChild("UICorner") ~= nil and bgImage.Size == UDim2.fromScale(1, 1), "the background should fill the window with rounded corners")
bgWin:SetBackgroundTransparency(0.7)
check(near(bgImage.ImageTransparency, 0.7), "SetBackgroundTransparency failed")
local shownImage = bgImage.Image
local bgOk, bgErr = bgWin:SetBackground("https://example.com/notfound")
check(not bgOk and bgErr ~= nil and bgImage.Image == shownImage and bgWin:GetBackground() == logoUrl, "a failed image should keep the current background")

bgWin:AddSettingsTab()
local bgInput = bgWin.Flags.MD3_Background
local bgSlider = bgWin.Flags.MD3_BackgroundTransparency
check(bgInput ~= nil and bgInput.Value == logoUrl and bgSlider ~= nil and bgSlider.Value == 70, "settings Background controls should show the current background")
bgWin:SaveConfig("bg")
bgInput:Set("")
check(not bgImage.Visible and bgWin:GetBackground() == nil, "clearing the background field should remove the background")
bgInput:Set("https://example.com/notfound")
check(bgInput.Value == "" and not bgImage.Visible and toasts(bgWin) == 1, "a bad URL should notify and put the field back")
bgSlider:Set(20)
check(near(bgImage.ImageTransparency, 0.2), "the transparency slider did not apply")
bgWin:SetBackground(logoUrl, 0.5)
check(bgInput.Value == logoUrl and bgSlider.Value == 50, "SetBackground from code should update the settings controls")
findElement(bgWin, "Remove background"):Fire()
check(not bgImage.Visible and bgInput.Value == "", "Remove background failed")
check(bgWin:LoadConfig("bg"), "loading the background config failed")
check(bgImage.Visible and bgWin:GetBackground() == logoUrl and near(bgImage.ImageTransparency, 0.7), "the background was not restored from the config")
bgWin:Destroy()

-- UIListLayout sorts by Name unless told otherwise, which scrambled the
-- dialog (actions above the title). Every layout must sort by LayoutOrder.
local layouts, unsorted = 0, 0
for _, inst in MOCK_INSTANCES do
	if inst.ClassName == "UIListLayout" then
		layouts += 1
		if inst.SortOrder ~= Enum.SortOrder.LayoutOrder then
			unsorted += 1
		end
	end
end
check(layouts > 50 and unsorted == 0, `{unsorted} of {layouts} UIListLayouts don't sort by LayoutOrder`)

-- Dialog: title, body, actions in that order; no full-size catcher inside the layout
local layoutWindow = MD3.CreateWindow({ Title = "Layout test", Parent = host })
local ordered = layoutWindow:Dialog({ Title = "T", Content = "C", Buttons = { { Title = "A" }, { Title = "B" } } })
local card = ordered._card
check(card.ClassName == "TextButton", "Dialog card should catch clicks itself")
check(card:FindFirstChild("CardCatcher") == nil, "Dialog still has a CardCatcher inside its layout")
check(card.Title.LayoutOrder < card.Body.LayoutOrder and card.Body.LayoutOrder < card.Actions.LayoutOrder, "Dialog content order wrong")
check(ordered._buttons[1].Instance.LayoutOrder < ordered._buttons[2].Instance.LayoutOrder, "Dialog action order wrong")
layoutWindow:Destroy()

print(`smoke test passed ({checks} checks)`)
