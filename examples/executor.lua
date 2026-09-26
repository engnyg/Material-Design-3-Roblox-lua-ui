--[[
	MD3 Hub v3 Executor Example — Paste into your executor and run.
	Showcases the complete hub_v3 architecture natively built into Material Design 3:
	1. Top navigation bar with smooth sliding pill indicator
	2. Sub-categories (AddSubTabs) with Left/Right dual columns & center divider
	3. Top-left instant settings search box & floating search dropdown
	4. Exponential damped lerp dragging with screen boundary clamping
	5. Fullscreen background dimming backdrop with fade transitions
	6. Snowfall particle system with sway physics
	7. Custom theme-tinted mouse cursor
	8. Rich Watermark HUD (Avatar, Player, Game, Executor, FPS, Ping, Clock)
	9. Window real-time scaling and transparency controls
]]

-- Clean up previous window on re-execution
if typeof(getgenv) == "function" and getgenv().CurrentMD3Window then
	pcall(function()
		getgenv().CurrentMD3Window:Destroy()
	end)
	getgenv().CurrentMD3Window = nil
end

local MD3
if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile("MaterialDesign3.luau") then
	MD3 = loadstring(readfile("MaterialDesign3.luau"))()
else
	MD3 = loadstring(game:HttpGet(
		"https://raw.githubusercontent.com/engnyg/Material-Design-3-Roblox-lua-ui/main/dist/MaterialDesign3.luau"
	))()
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Window = MD3:CreateWindow({
	Title = "MD3 Hub",
	Subtitle = "v3.0 Architecture",
	Size = UDim2.fromOffset(720, 460),
	Mode = "Dark",
	ThemeColor = Color3.fromHex("#6750A4"),
	ToggleKey = Enum.KeyCode.RightShift,
	ConfigFolder = "MD3Hub",

	-- hub_v3 Visuals & Systems:
	Search = true,              -- Top-left setting search box & floating dropdown
	SearchPlaceholder = "Search settings...",
	Backdrop = true,            -- Fullscreen dark dimming overlay with fade tween
	Snowfall = true,            -- Snow particle effects behind the UI
	CustomCursor = false,       -- false to use standard mouse; true for custom colored cursor
	Transparency = 0.15,        -- Default glassmorphism window transparency
})

if typeof(getgenv) == "function" then
	getgenv().CurrentMD3Window = Window
end

local function getHumanoid()
	local character = LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- ==================== 1. Player Tab (SubTabs + Dual Columns) ====================
local PlayerTab = Window:AddTab({ Title = "Player", Icon = "person" })
local PlayerSubs = PlayerTab:AddSubTabs({ "Movement", "Stats" })

-- Player -> Movement SubTab
local MoveLeft = PlayerSubs.Movement:AddLeftSection("Movement Modifiers")
MoveLeft:AddSlider({
	Title = "WalkSpeed",
	Min = 16,
	Max = 200,
	Default = 16,
	Step = 1,
	Flag = "WalkSpeed",
	Callback = function(value)
		local h = getHumanoid()
		if h then
			h.WalkSpeed = value
		end
	end,
})

MoveLeft:AddSlider({
	Title = "JumpPower",
	Min = 50,
	Max = 300,
	Default = 50,
	Step = 5,
	Flag = "JumpPower",
	Callback = function(value)
		local h = getHumanoid()
		if h then
			h.UseJumpPower = true
			h.JumpPower = value
		end
	end,
})

local infiniteJump = false
MoveLeft:AddToggle({
	Title = "Infinite Jump",
	Description = "Jump freely while in the air",
	Default = false,
	Flag = "InfiniteJump",
	Callback = function(on)
		infiniteJump = on
	end,
})

local jumpConnection = game:GetService("UserInputService").JumpRequest:Connect(function()
	local h = getHumanoid()
	if infiniteJump and h then
		h:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

MoveLeft:AddKeybind({
	Title = "Quick Reset Speed",
	Default = Enum.KeyCode.R,
	Callback = function()
		Window.Flags.WalkSpeed:Set(16)
		Window:Notify({ Title = "WalkSpeed reset", Icon = "speed", Duration = 2 })
	end,
})

local MoveRight = PlayerSubs.Movement:AddRightSection("Utility Actions")
MoveRight:AddButton({
	Title = "Rejoin Server",
	Description = "Teleport back into the current server",
	Icon = "refresh",
	IconColor = "Tertiary",
	Callback = function()
		game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
	end,
})

MoveRight:AddButton({
	Title = "Copy JobId",
	Description = "Copy server JobId to clipboard",
	Icon = "content_copy",
	Callback = function()
		local ok = MD3.Env.SetClipboard(game.JobId)
		Window:Notify({
			Title = ok and "Copied" or "Clipboard unavailable",
			Content = game.JobId,
			Icon = "content_copy",
		})
	end,
})

-- Player -> Stats SubTab
local StatsLeft = PlayerSubs.Stats:AddLeftSection("Character Status")
StatsLeft:AddParagraph({
	Title = "Account Information",
	Content = `User: {LocalPlayer.Name} (@{LocalPlayer.DisplayName})\nUserId: {LocalPlayer.UserId}`,
})

local StatsRight = PlayerSubs.Stats:AddRightSection("Server Diagnostics")
StatsRight:AddParagraph({
	Title = "Place Info",
	Content = `PlaceId: {game.PlaceId}\nJobId: {game.JobId}`,
})

-- ==================== 2. Visuals Tab (Effects, Backdrop, Scaling) ====================
local VisualsTab = Window:AddTab({ Title = "Visuals", Icon = "palette" })
local VisualSubs = VisualTab:AddSubTabs({ "Snow & Dim", "Window & Cursor" })

-- Visuals -> Snow & Dim
local SnowLeft = VisualSubs["Snow & Dim"]:AddLeftSection("Snowfall Particle System")
SnowLeft:AddToggle({
	Title = "Enable Snowfall",
	Description = "Smooth animated falling snowflakes behind UI",
	Default = true,
	Callback = function(enabled)
		Window:SetSnowfall(enabled)
	end,
})

SnowLeft:AddSlider({
	Title = "Snowfall Speed",
	Min = 5,
	Max = 30,
	Default = 10,
	Callback = function(val)
		Window:SetSnowfall(nil, nil, val / 10)
	end,
})

SnowLeft:AddSlider({
	Title = "Snowflake Count",
	Min = 10,
	Max = 120,
	Default = 45,
	Callback = function(val)
		Window:SetSnowfall(nil, val)
	end,
})

local DimRight = VisualSubs["Snow & Dim"]:AddRightSection("Backdrop Dimming")
DimRight:AddToggle({
	Title = "Enable Background Dim",
	Description = "Darkens game background while window is visible",
	Default = true,
	Callback = function(enabled)
		Window:SetBackdrop(enabled)
	end,
})

DimRight:AddSlider({
	Title = "Dim Transparency",
	Min = 10,
	Max = 90,
	Default = 55,
	Callback = function(val)
		Window:SetBackdrop(nil, val / 100)
	end,
})

-- Visuals -> Window & Cursor
local WinLeft = VisualSubs["Window & Cursor"]:AddLeftSection("Window Sizing & Glass")
WinLeft:AddSlider({
	Title = "UI Scale",
	Min = 60,
	Max = 150,
	Default = 100,
	Callback = function(val)
		Window:SetScale(val / 100)
	end,
})

WinLeft:AddSlider({
	Title = "UI Transparency",
	Min = 0,
	Max = 80,
	Default = 15,
	Callback = function(val)
		Window:SetTransparency(val / 100)
	end,
})

local CurRight = VisualSubs["Window & Cursor"]:AddRightSection("Custom Mouse Cursor")
CurRight:AddToggle({
	Title = "Enable Custom Cursor",
	Description = "Replaces default mouse with theme-tinted pointer",
	Default = true,
	Callback = function(enabled)
		Window:SetCustomCursor(enabled)
	end,
})

CurRight:AddSlider({
	Title = "Cursor Scale",
	Min = 50,
	Max = 200,
	Default = 100,
	Callback = function(val)
		Window:SetCustomCursor(nil, val)
	end,
})

-- ==================== 3. Elements Tab (Showcasing all MD3 elements) ====================
local ElementsTab = Window:AddTab({ Title = "Elements", Icon = "widgets" })
local ElemSubs = ElementsTab:AddSubTabs({ "Controls", "Dialogs" })

local ControlsLeft = ElemSubs.Controls:AddLeftSection("Selection & Inputs")
local playerDropdown = ControlsLeft:AddDropdown({
	Title = "Select Player",
	Options = {},
	Flag = "TargetPlayer",
	Callback = function(name)
		print("Selected player:", name)
	end,
})

local function refreshPlayers()
	local names = {}
	for _, p in Players:GetPlayers() do
		table.insert(names, p.Name)
	end
	playerDropdown:SetOptions(names)
end
refreshPlayers()
local addedConnection = Players.PlayerAdded:Connect(refreshPlayers)
local removingConnection = Players.PlayerRemoving:Connect(refreshPlayers)

ControlsLeft:AddDropdown({
	Title = "Multi-Select Features",
	Description = "Select multiple options",
	Options = { "ESP", "Tracers", "Chams", "Skeleton", "HealthBar" },
	Multi = true,
	Default = { "ESP" },
	Flag = "ActiveFeatures",
	Callback = function(list)
		print("Features:", table.concat(list, ", "))
	end,
})

ControlsLeft:AddInput({
	Title = "Custom Tag",
	Placeholder = "Enter text...",
	ClearOnSubmit = true,
	Callback = function(text)
		print("Tag entered:", text)
	end,
})

local ControlsRight = ElemSubs.Controls:AddRightSection("Colors & Keybinds")
ControlsRight:AddColorPicker({
	Title = "Accent Color",
	Default = Color3.fromRGB(180, 140, 255),
	Flag = "CustomAccent",
	Callback = function(color)
		print("Color selected:", color:ToHex())
	end,
})

ControlsRight:AddKeybind({
	Title = "Hold to Sprint",
	Mode = "Hold",
	Default = Enum.KeyCode.LeftShift,
	Flag = "SprintKey",
	Callback = function(held)
		local h = getHumanoid()
		if h then
			h.WalkSpeed = held and 32 or (Window.Flags.WalkSpeed and Window.Flags.WalkSpeed.Value or 16)
		end
	end,
})

-- Elements -> Dialogs
local DialogsLeft = ElemSubs.Dialogs:AddLeftSection("Material Dialogs")
DialogsLeft:AddButton({
	Title = "Show Material Dialog",
	Icon = "open_in_new",
	Callback = function()
		Window:Dialog({
			Title = "Material Design 3 Dialog",
			Content = "This dialog uses the native MD3 modal system with responsive buttons.",
			Buttons = {
				{ Title = "Cancel" },
				{
					Title = "Confirm",
					Variant = "Filled",
					Callback = function()
						Window:Notify({
							Title = "Action Confirmed",
							Content = "Operation executed successfully.",
							Icon = "check_circle",
						})
					end,
				},
			},
		})
	end,
})

-- ==================== 4. Watermark HUD ====================
local Watermark = Window:AddWatermark({
	Title = "MD3 Hub v3",
	Position = "TopLeft",
})
Watermark:AddAvatar()
Watermark:AddPlayer()
Watermark:AddGame()
Watermark:AddExecutor()
Watermark:AddFPS()
Watermark:AddPing()
Watermark:AddClock()

Window:AddKeybindList()

local jumpIndicator = Window:AddIndicator({ Text = "INF JUMP", Icon = "bolt", Visible = infiniteJump })
if Window.Flags.InfiniteJump then
	Window.Flags.InfiniteJump:OnChanged(function(on)
		jumpIndicator:SetVisible(on)
	end)
end

-- ==================== 5. Built-in Settings Tab ====================
Window:AddSettingsTab()

-- Teardown
Window.OnUnload:Connect(function()
	pcall(function() jumpConnection:Disconnect() end)
	pcall(function() addedConnection:Disconnect() end)
	pcall(function() removingConnection:Disconnect() end)
end)

Window:LoadAutoloadConfig()

Window:Notify({
	Title = "MD3 Hub v3 Loaded",
	Content = `Press {Enum.KeyCode.RightShift.Name} to toggle window.`,
	Icon = "check_circle",
})
