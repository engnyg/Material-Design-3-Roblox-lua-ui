--[[
	MD3 executor example — paste into your executor and run.
	Shows every element type, notifications, a dialog and the built-in
	settings tab (theme, accent color, toggle key, configs).
]]
local MD3 = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/engnyg/Material-Design-3-Roblox-lua-ui/main/dist/MaterialDesign3.luau"
))()

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Window = MD3:CreateWindow({
	Title = "MD3 Hub",
	Subtitle = "Material Design 3 for executors",
	Icon = "widgets",
	-- Logo = "https://.../logo.png",   -- a colored image shown as-is instead of Icon
	Mode = "Dark",
	ThemeColor = Color3.fromHex("#6750A4"), -- also adjustable live: Settings > Appearance
	-- IconColor = Color3.fromRGB(255, 200, 0), -- every icon
	-- TextColor = Color3.fromRGB(230, 230, 255), -- all text
	ToggleKey = Enum.KeyCode.RightShift,
	ConfigFolder = "MD3Hub",
})

--== Player tab ==--
local PlayerTab = Window:AddTab({ Title = "Player", Icon = "person" })

local Movement = PlayerTab:AddSection("Movement")

local function humanoid()
	local character = LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

Movement:AddSlider({
	Title = "WalkSpeed",
	Min = 16,
	Max = 200,
	Default = 16,
	Step = 1,
	Flag = "WalkSpeed",
	Callback = function(value)
		local h = humanoid()
		if h then
			h.WalkSpeed = value
		end
	end,
})

Movement:AddSlider({
	Title = "JumpPower",
	Min = 50,
	Max = 300,
	Default = 50,
	Step = 5,
	Flag = "JumpPower",
	Callback = function(value)
		local h = humanoid()
		if h then
			h.UseJumpPower = true
			h.JumpPower = value
		end
	end,
})

local infiniteJump = false
Movement:AddToggle({
	Title = "Infinite jump",
	Description = "Jump again while in the air",
	Default = false,
	Flag = "InfiniteJump",
	Callback = function(on)
		infiniteJump = on
	end,
})
local jumpConnection = game:GetService("UserInputService").JumpRequest:Connect(function()
	local h = humanoid()
	if infiniteJump and h then
		h:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

Movement:AddKeybind({
	Title = "Quick reset speed",
	Default = Enum.KeyCode.R,
	Callback = function()
		Window.Flags.WalkSpeed:Set(16)
		Window:Notify({ Title = "WalkSpeed reset", Icon = "speed", Duration = 2 })
	end,
})

local Misc = PlayerTab:AddSection("Misc")
Misc:AddButton({
	Title = "Rejoin",
	Description = "Teleport back into this server",
	Icon = "refresh",
	IconColor = "Tertiary", -- per-icon color: a theme role, or a Color3
	Callback = function()
		game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
	end,
})
Misc:AddButton({
	Title = "Copy JobId",
	Icon = "content_copy",
	Callback = function()
		local ok = MD3.Env.SetClipboard(game.JobId)
		Window:Notify({ Title = ok and "Copied" or "Clipboard unavailable", Content = game.JobId, Icon = "content_copy" })
	end,
})

--== Elements tab: one of everything ==--
-- Icon / Logo / Image props also take image URLs: downloaded once, then
-- loaded through getcustomasset (see MD3.Assets). Icon images get tinted with
-- the theme color, so they must be WHITE: ImageColor3 multiplies, and black
-- stays black whatever the tint (Google's own PNGs are black - use Logo /
-- Image for colored images, which aren't tinted).
local Demo = Window:AddTab({
	Title = "Elements",
	Icon = "https://raw.githubusercontent.com/engnyg/Material-Design-3-Roblox-lua-ui/main/assets/examples/extension.png",
})

Demo:AddParagraph({
	Title = "About",
	Content = "Every element supports Flag (saved in configs), Callback, :Set(), :Get() and :OnChanged().",
})

local playerDropdown = Demo:AddDropdown({
	Title = "Target player",
	Options = {},
	Flag = "Target",
	Callback = function(name)
		print("Target:", name)
	end,
})
local function refreshPlayers()
	local names = {}
	for _, player in Players:GetPlayers() do
		table.insert(names, player.Name)
	end
	playerDropdown:SetOptions(names)
end
refreshPlayers()
local addedConnection = Players.PlayerAdded:Connect(refreshPlayers)
local removingConnection = Players.PlayerRemoving:Connect(refreshPlayers)

Demo:AddDropdown({
	Title = "Features",
	Description = "Multi-select",
	Options = { "ESP", "Tracers", "Names", "Health bars" },
	Multi = true,
	Default = { "ESP" },
	Flag = "Features",
	Callback = function(list)
		print("Features:", table.concat(list, ", "))
	end,
})

Demo:AddInput({
	Title = "Chat message",
	Placeholder = "Type and press Enter",
	ClearOnSubmit = true,
	Callback = function(text)
		print("Input:", text)
	end,
})

Demo:AddColorPicker({
	Title = "ESP color",
	Default = Color3.fromRGB(255, 80, 80),
	Flag = "EspColor",
	Callback = function(color)
		print("Color:", color:ToHex())
	end,
})

Demo:AddKeybind({
	Title = "Hold to sprint",
	Mode = "Hold",
	Default = Enum.KeyCode.LeftShift,
	Flag = "SprintKey",
	Callback = function(held)
		local h = humanoid()
		if h then
			h.WalkSpeed = held and 32 or Window.Flags.WalkSpeed.Value
		end
	end,
})

Demo:AddDivider()
Demo:AddLabel("Labels are plain text, e.g. for status lines.")

Demo:AddButton({
	Title = "Show a dialog",
	Icon = "open_in_new",
	Callback = function()
		Window:Dialog({
			Title = "Material dialog",
			Content = "Dialogs use the MD3 Dialog component.",
			Buttons = {
				{ Title = "Cancel" },
				{
					Title = "Notify me",
					Variant = "Filled",
					Callback = function()
						Window:Notify({ Title = "Hello!", Content = "From the dialog", Icon = "notifications" })
					end,
				},
			},
		})
	end,
})

--== HUD: stays on screen while the window is hidden; drag any piece to move it ==--
local Watermark = Window:AddWatermark({ FPS = true, Ping = true, Clock = true })
Watermark:AddBlock({ Icon = "person", Text = LocalPlayer.DisplayName })

Window:AddKeybindList() -- shows "Hold to sprint" while LeftShift is held

local jumpIndicator = Window:AddIndicator({ Text = "INF JUMP", Icon = "bolt", Visible = infiniteJump })
Window.Flags.InfiniteJump:OnChanged(function(on)
	jumpIndicator:SetVisible(on)
end)

--== Settings tab (theme / accent / theme editor / toggle key / configs) ==--
-- Added after the HUD, so it also gets a "Show HUD" switch.
Window:AddSettingsTab()

-- Stop everything this script started when the UI is unloaded.
Window.OnUnload:Connect(function()
	jumpConnection:Disconnect()
	addedConnection:Disconnect()
	removingConnection:Disconnect()
end)

-- Must run after every flagged element exists.
Window:LoadAutoloadConfig()

Window:Notify({
	Title = "MD3 Hub loaded",
	Content = `Press {Enum.KeyCode.RightShift.Name} to hide / show.`,
	Icon = "check_circle",
})
