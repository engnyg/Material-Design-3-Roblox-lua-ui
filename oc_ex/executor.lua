--[[
	MD3 Hub v3 - Material Design 3 Category & Subcategory Architecture
	Example directly mirroring hub_v3.luau using clean native library APIs:
	1. Top horizontal sliding navigation pill
	2. Sub-categories with dual columns (LeftCol / RightCol) and center DividerLine
	3. Top-left instant settings search box with dropdown & pulse highlight
	4. Damped exponential lerp dragging with boundary clamping
	5. Fullscreen background dimming backdrop with fade transitions
	6. Snowfall particle system with sway physics
	7. Rich Watermark HUD (Avatar, Player, Game, Executor, FPS, Ping, Clock)
	8. Window real-time scaling and transparency controls
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
	Title = "LY Hub",
	Subtitle = "v3.0 Architecture",
	Size = UDim2.fromOffset(720, 460),
	Mode = "Dark",
	ThemeColor = Color3.fromHex("#6750A4"),
	ToggleKey = Enum.KeyCode.RightShift,
	ConfigFolder = "LYHub",

	-- hub_v3 Visuals & Systems:
	Search = true,              -- Top-left setting search box & floating dropdown
	SearchPlaceholder = "Search settings...",
	Backdrop = true,            -- Fullscreen dark dimming overlay with fade tween
	Snowfall = true,            -- Snow particle effects behind the UI
	CustomCursor = false,       -- Standard hardware mouse (smooth in FPS games)
	Transparency = 0.15,        -- Default glassmorphism window transparency
})

if typeof(getgenv) == "function" then
	getgenv().CurrentMD3Window = Window
end

local function getHumanoid()
	local character = LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- ==================== 1. Main Category ====================
local MainTab = Window:AddTab({ Title = "Main", Icon = "home" })
local MainSubs = MainTab:AddSubTabs({ "Overview", "Statistics", "Info" })

-- Main -> Overview
local Main_1_L = MainSubs.Overview:AddLeftSection("General")
Main_1_L:AddParagraph({
	Title = "Welcome to LY Hub",
	Content = "Modern Material Design 3 interface with background dimming, snowfall effect, and dual-column layouts.",
})
Main_1_L:AddToggle({
	Title = "Auto Initialize",
	Default = true,
	Flag = "Main_AutoInit",
	Callback = function(on)
		print("AutoInit:", on)
	end,
})

local Main_1_R = MainSubs.Overview:AddRightSection("System Info")
Main_1_R:AddParagraph({
	Title = "Core Status",
	Content = "Threads running normally. Dual-column structure initialized.",
})
Main_1_R:AddButton({
	Title = "Refresh State",
	Icon = "refresh",
	Callback = function()
		Window:Notify({ Title = "System Refreshed", Icon = "check_circle", Duration = 2 })
	end,
})

-- Main -> Statistics
local Main_2_L = MainSubs.Statistics:AddLeftSection("Session Stats")
Main_2_L:AddParagraph({
	Title = "Active Session",
	Content = `User: {LocalPlayer.Name} (@{LocalPlayer.DisplayName})\nUserId: {LocalPlayer.UserId}`,
})

local Main_2_R = MainSubs.Statistics:AddRightSection("Performance Monitor")
Main_2_R:AddParagraph({
	Title = "Server Details",
	Content = `PlaceId: {game.PlaceId}\nJobId: {game.JobId}`,
})

-- Main -> Info
local Main_3_L = MainSubs.Info:AddLeftSection("System Diagnostics")
Main_3_L:AddLabel("All systems operating within normal parameters.")

local Main_3_R = MainSubs.Info:AddRightSection("Build Information")
Main_3_R:AddParagraph({
	Title = "Version",
	Content = "MD3 Engine v3.0 (Native Hub Architecture)",
})

-- ==================== 2. Combat Category ====================
local CombatTab = Window:AddTab({ Title = "Combat", Icon = "shield" })
local CombatSubs = CombatTab:AddSubTabs({ "Aimbot", "Silent Bot", "Trigger Bot" })

-- Combat -> Aimbot
local Combat_1_L = CombatSubs.Aimbot:AddLeftSection("Targeting")
Combat_1_L:AddToggle({
	Title = "Enable Aimbot",
	Default = false,
	Flag = "Combat_Aimbot",
})
Combat_1_L:AddDropdown({
	Title = "Target Part",
	Options = { "Head", "Torso", "HumanoidRootPart" },
	Default = "Head",
	Flag = "Combat_TargetPart",
})
Combat_1_L:AddSlider({
	Title = "Smoothness",
	Min = 1,
	Max = 20,
	Default = 5,
	Flag = "Combat_Smoothness",
})
Combat_1_L:AddSlider({
	Title = "FOV Radius",
	Min = 30,
	Max = 300,
	Default = 120,
	Flag = "Combat_FOV",
})

local Combat_1_R = CombatSubs.Aimbot:AddRightSection("Target Filtering")
Combat_1_R:AddToggle({
	Title = "Team Check",
	Default = true,
	Flag = "Combat_TeamCheck",
})
Combat_1_R:AddToggle({
	Title = "Visible Check",
	Default = true,
	Flag = "Combat_VisibleCheck",
})

-- Combat -> Silent Bot
local Combat_2_L = CombatSubs["Silent Bot"]:AddLeftSection("Trigger Conditions")
Combat_2_L:AddToggle({
	Title = "Silent Aim",
	Default = false,
	Flag = "Combat_SilentAim",
})
Combat_2_L:AddSlider({
	Title = "Hit Chance",
	Min = 0,
	Max = 100,
	Default = 100,
	Suffix = "%",
	Flag = "Combat_HitChance",
})

local Combat_2_R = CombatSubs["Silent Bot"]:AddRightSection("Hitbox Configuration")
Combat_2_R:AddDropdown({
	Title = "Priority Hitbox",
	Options = { "Head", "UpperTorso", "Random" },
	Default = "Head",
	Flag = "Combat_Hitbox",
})

-- Combat -> Trigger Bot
local Combat_3_L = CombatSubs["Trigger Bot"]:AddLeftSection("Activation Mode")
Combat_3_L:AddToggle({
	Title = "Enable Triggerbot",
	Default = false,
	Flag = "Combat_Triggerbot",
})

local Combat_3_R = CombatSubs["Trigger Bot"]:AddRightSection("Delay & Safety")
Combat_3_R:AddSlider({
	Title = "Trigger Delay",
	Min = 0,
	Max = 250,
	Default = 30,
	Suffix = " ms",
	Flag = "Combat_TriggerDelay",
})

-- ==================== 3. Visuals Category ====================
local VisualsTab = Window:AddTab({ Title = "Visuals", Icon = "visibility" })
local VisualsSubs = VisualsTab:AddSubTabs({ "ESP", "Chams", "World" })

-- Visuals -> ESP
local Vis_1_L = VisualsSubs.ESP:AddLeftSection("Player ESP")
Vis_1_L:AddToggle({
	Title = "Box ESP",
	Default = false,
	Flag = "ESP_Box",
})
Vis_1_L:AddDropdown({
	Title = "Box Type",
	Options = { "2D Box", "3D Box", "Corner Box" },
	Default = "2D Box",
	Flag = "ESP_BoxType",
})
Vis_1_L:AddColorPicker({
	Title = "Box Color",
	Default = Color3.fromRGB(255, 255, 255),
	Flag = "ESP_BoxColor",
})

local Vis_1_R = VisualsSubs.ESP:AddRightSection("Distance & Tracers")
Vis_1_R:AddToggle({
	Title = "Show Distance",
	Default = false,
	Flag = "ESP_Distance",
})
Vis_1_R:AddToggle({
	Title = "Snaplines / Tracers",
	Default = false,
	Flag = "ESP_Tracers",
})
Vis_1_R:AddToggle({
	Title = "Show Healthbar",
	Default = false,
	Flag = "ESP_Health",
})

-- Visuals -> Chams
local Vis_2_L = VisualsSubs.Chams:AddLeftSection("Chams")
Vis_2_L:AddToggle({
	Title = "Enable Chams",
	Default = false,
	Flag = "Chams_Enable",
})
Vis_2_L:AddColorPicker({
	Title = "Chams Visible Color",
	Default = Color3.fromRGB(0, 255, 128),
	Flag = "Chams_VisColor",
})

local Vis_2_R = VisualsSubs.Chams:AddRightSection("Skeleton")
Vis_2_R:AddToggle({
	Title = "Enable Skeleton",
	Default = false,
	Flag = "Skeleton_Enable",
})

-- Visuals -> World
local Vis_3_L = VisualsSubs.World:AddLeftSection("Render Effects")
Vis_3_L:AddToggle({
	Title = "Fullbright",
	Default = false,
	Flag = "World_Fullbright",
})

local Vis_3_R = VisualsSubs.World:AddRightSection("Post Processing")
Vis_3_R:AddToggle({
	Title = "Disable Shadows",
	Default = false,
	Flag = "World_NoShadows",
})

-- ==================== 4. Player Category ====================
local PlayerTab = Window:AddTab({ Title = "Player", Icon = "person" })
local PlayerSubs = PlayerTab:AddSubTabs({ "Movement", "Character", "Camera" })

-- Player -> Movement
local Play_1_L = PlayerSubs.Movement:AddLeftSection("Movement Attributes")
Play_1_L:AddSlider({
	Title = "WalkSpeed",
	Min = 16,
	Max = 200,
	Default = 16,
	Step = 1,
	Flag = "Player_WalkSpeed",
	Callback = function(val)
		local h = getHumanoid()
		if h then h.WalkSpeed = val end
	end,
})
Play_1_L:AddSlider({
	Title = "JumpPower",
	Min = 50,
	Max = 300,
	Default = 50,
	Step = 5,
	Flag = "Player_JumpPower",
	Callback = function(val)
		local h = getHumanoid()
		if h then
			h.UseJumpPower = true
			h.JumpPower = val
		end
	end,
})

local infiniteJump = false
Play_1_L:AddToggle({
	Title = "Infinite Jump",
	Description = "Jump freely in mid-air",
	Default = false,
	Flag = "Player_InfiniteJump",
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

Play_1_L:AddKeybind({
	Title = "Quick Reset Speed",
	Default = Enum.KeyCode.R,
	Callback = function()
		Window.Flags.Player_WalkSpeed:Set(16)
		Window:Notify({ Title = "WalkSpeed reset", Icon = "speed", Duration = 2 })
	end,
})

local Play_1_R = PlayerSubs.Movement:AddRightSection("Velocity Modifiers")
Play_1_R:AddButton({
	Title = "Rejoin Server",
	Icon = "refresh",
	IconColor = "Tertiary",
	Callback = function()
		game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
	end,
})
Play_1_R:AddButton({
	Title = "Copy JobId",
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

-- Player -> Character
local Play_2_L = PlayerSubs.Character:AddLeftSection("Physics Simulation")
Play_2_L:AddToggle({
	Title = "Noclip",
	Default = false,
	Flag = "Player_Noclip",
})

local Play_2_R = PlayerSubs.Character:AddRightSection("State & Attributes")
Play_2_R:AddToggle({
	Title = "Anti-Ragdoll",
	Default = false,
	Flag = "Player_AntiRagdoll",
})

-- Player -> Camera
local Play_3_L = PlayerSubs.Camera:AddLeftSection("Field of View")
Play_3_L:AddSlider({
	Title = "Custom FOV",
	Min = 70,
	Max = 120,
	Default = 70,
	Flag = "Player_FOV",
	Callback = function(val)
		local cam = workspace.CurrentCamera
		if cam then cam.FieldOfView = val end
	end,
})

local Play_3_R = PlayerSubs.Camera:AddRightSection("Perspective Controls")
Play_3_R:AddToggle({
	Title = "Third Person",
	Default = false,
	Flag = "Player_ThirdPerson",
})

-- ==================== 5. World Category ====================
local WorldTab = Window:AddTab({ Title = "World", Icon = "public" })
local WorldSubs = WorldTab:AddSubTabs({ "Lighting", "Environment", "Atmosphere" })

local World_1_L = WorldSubs.Lighting:AddLeftSection("Lighting Effects")
World_1_L:AddSlider({
	Title = "Brightness",
	Min = 0,
	Max = 10,
	Default = 2,
	Flag = "World_Brightness",
})

local World_1_R = WorldSubs.Lighting:AddRightSection("Shadows & Bloom")
World_1_R:AddToggle({
	Title = "Global Shadows",
	Default = true,
	Flag = "World_Shadows",
})

local World_2_L = WorldSubs.Environment:AddLeftSection("Weather Systems")
World_2_L:AddToggle({
	Title = "Clear Fog",
	Default = false,
	Flag = "World_ClearFog",
})

local World_2_R = WorldSubs.Environment:AddRightSection("Time of Day")
World_2_R:AddSlider({
	Title = "Clock Time",
	Min = 0,
	Max = 24,
	Default = 14,
	Flag = "World_ClockTime",
})

local World_3_L = WorldSubs.Atmosphere:AddLeftSection("Asset Streaming")
World_3_L:AddLabel("Stream assets smoothly in foreground.")

local World_3_R = WorldSubs.Atmosphere:AddRightSection("Ambient Physics")
World_3_R:AddLabel("Gravity & atmospheric density controls.")

-- ==================== 6. Misc Category ====================
local MiscTab = Window:AddTab({ Title = "Misc", Icon = "more_horiz" })
local MiscSubs = MiscTab:AddSubTabs({ "Utilities", "Game", "Debug" })

local Misc_1_L = MiscSubs.Utilities:AddLeftSection("Server Actions")
Misc_1_L:AddButton({
	Title = "Server Hop",
	Icon = "shuffle",
	Callback = function()
		Window:Notify({ Title = "Searching for server...", Icon = "info", Duration = 2 })
	end,
})

local Misc_1_R = MiscSubs.Utilities:AddRightSection("Connection State")
Misc_1_R:AddParagraph({
	Title = "Ping State",
	Content = "Active WebSocket / HTTP Polling connection stable.",
})

local Misc_2_L = MiscSubs.Game:AddLeftSection("General Tools")
Misc_2_L:AddButton({
	Title = "Show Dialog Demo",
	Icon = "open_in_new",
	Callback = function()
		Window:Dialog({
			Title = "LY Hub Dialog",
			Content = "This is a native Material Design 3 Dialog component.",
			Buttons = {
				{ Title = "Cancel" },
				{
					Title = "Confirm",
					Variant = "Filled",
					Callback = function()
						Window:Notify({ Title = "Confirmed", Icon = "check_circle" })
					end,
				},
			},
		})
	end,
})

local Misc_2_R = MiscSubs.Game:AddRightSection("Hotkeys & Keybinds")
Misc_2_R:AddKeybind({
	Title = "Sprint Keybind",
	Mode = "Hold",
	Default = Enum.KeyCode.LeftShift,
	Flag = "Misc_SprintKey",
	Callback = function(held)
		local h = getHumanoid()
		if h then
			h.WalkSpeed = held and 32 or (Window.Flags.Player_WalkSpeed and Window.Flags.Player_WalkSpeed.Value or 16)
		end
	end,
})

local Misc_3_L = MiscSubs.Debug:AddLeftSection("Diagnostics")
Misc_3_L:AddLabel("Memory and instance tracker active.")

local Misc_3_R = MiscSubs.Debug:AddRightSection("Console & Logs")
Misc_3_R:AddButton({
	Title = "Clear Output",
	Icon = "delete",
	Callback = function()
		Window:Notify({ Title = "Logs Cleared", Duration = 2 })
	end,
})

-- ==================== 7. Settings Category (HUD, Themes, Config) ====================
local SettingsTab = Window:AddTab({ Title = "Settings", Icon = "settings" })
local SettSubs = SettingsTab:AddSubTabs({ "HUD", "Themes", "Config" })

-- Settings -> HUD
local Sett_HUD_L = SettSubs.HUD:AddLeftSection("Window Appearance")
Sett_HUD_L:AddSlider({
	Title = "UI Transparency",
	Min = 0,
	Max = 80,
	Default = 15,
	Flag = "Settings_Transparency",
	Callback = function(val)
		Window:SetTransparency(val / 100)
	end,
})
Sett_HUD_L:AddSlider({
	Title = "UI Scale",
	Min = 60,
	Max = 150,
	Default = 100,
	Flag = "Settings_Scale",
	Callback = function(val)
		Window:SetScale(val / 100)
	end,
})
Sett_HUD_L:AddToggle({
	Title = "Enable Custom Cursor",
	Default = false,
	Flag = "Settings_CustomCursor",
	Callback = function(enabled)
		Window:SetCustomCursor(enabled)
	end,
})

local Sett_HUD_R = SettSubs.HUD:AddRightSection("Background Dimming & Snow")
Sett_HUD_R:AddToggle({
	Title = "Enable Background Dim",
	Default = true,
	Flag = "Settings_Backdrop",
	Callback = function(enabled)
		Window:SetBackdrop(enabled)
	end,
})
Sett_HUD_R:AddSlider({
	Title = "Dim Transparency",
	Min = 10,
	Max = 90,
	Default = 55,
	Flag = "Settings_DimTransparency",
	Callback = function(val)
		Window:SetBackdrop(nil, val / 100)
	end,
})
Sett_HUD_R:AddToggle({
	Title = "Enable Snowfall",
	Default = true,
	Flag = "Settings_Snowfall",
	Callback = function(enabled)
		Window:SetSnowfall(enabled)
	end,
})
Sett_HUD_R:AddSlider({
	Title = "Snowfall Speed",
	Min = 5,
	Max = 30,
	Default = 10,
	Flag = "Settings_SnowSpeed",
	Callback = function(val)
		Window:SetSnowfall(nil, nil, val / 10)
	end,
})

-- Settings -> Themes
local Sett_Theme_L = SettSubs.Themes:AddLeftSection("Dark Mode & Presets")
Sett_Theme_L:AddToggle({
	Title = "Dark Mode",
	Default = true,
	Flag = "Settings_DarkMode",
	Callback = function(dark)
		Window.Theme:SetMode(dark and "Dark" or "Light")
	end,
})

local Sett_Theme_R = SettSubs.Themes:AddRightSection("Colors")
Sett_Theme_R:AddColorPicker({
	Title = "Primary Theme Color",
	Default = Color3.fromHex("#6750A4"),
	Flag = "Settings_ThemeColor",
	Callback = function(color)
		Window.Theme:SetThemeColor(color)
	end,
})

-- Settings -> Config
local Sett_Config_L = SettSubs.Config:AddLeftSection("Configuration Manager")
Sett_Config_L:AddInput({
	Title = "Config Name",
	Placeholder = "default",
	Flag = "Settings_ConfigName",
})
Sett_Config_L:AddButton({
	Title = "Save Config",
	Icon = "save",
	Callback = function()
		local name = Window.Flags.Settings_ConfigName and Window.Flags.Settings_ConfigName.Value or "default"
		Window:SaveConfig(name)
		Window:Notify({ Title = "Config Saved", Content = name, Icon = "check_circle" })
	end,
})
Sett_Config_L:AddButton({
	Title = "Load Config",
	Icon = "file_download",
	Callback = function()
		local name = Window.Flags.Settings_ConfigName and Window.Flags.Settings_ConfigName.Value or "default"
		Window:LoadConfig(name)
		Window:Notify({ Title = "Config Loaded", Content = name, Icon = "check_circle" })
	end,
})

local Sett_Config_R = SettSubs.Config:AddRightSection("Autoload Configuration")
Sett_Config_R:AddButton({
	Title = "Set as Autoload",
	Icon = "star",
	Callback = function()
		local name = Window.Flags.Settings_ConfigName and Window.Flags.Settings_ConfigName.Value or "default"
		Window:SetAutoLoad(name)
		Window:Notify({ Title = "Autoload Set", Content = name, Icon = "star" })
	end,
})

-- ==================== 8. HUD Elements (Watermark & Keybinds) ====================
local Watermark = Window:AddWatermark({
	Title = "LY Hub",
	Position = "TopLeft",
})
Watermark:AddAvatar()
Watermark:AddPlayer()
Watermark:AddGame()
Watermark:AddExecutor()
Watermark:AddFPS()
Watermark:AddPing()
Watermark:AddClock()

Window:AddKeybindList({
	Title = "Keybinds",
	Position = "Left",
	ShowAll = true,
})

-- Teardown
Window.OnUnload:Connect(function()
	pcall(function() jumpConnection:Disconnect() end)
end)

Window:LoadAutoloadConfig()

Window:Notify({
	Title = "LY Hub Loaded",
	Content = `Press {Enum.KeyCode.RightShift.Name} to toggle window.`,
	Icon = "check_circle",
})
