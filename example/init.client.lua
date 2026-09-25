--[[
	Demo / smoke test for the MD3 library. Sync this with Rojo into
	StarterPlayerScripts (see default.project.json) and run the game —
	it builds a small settings-style screen exercising most components.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MD3 = require(ReplicatedStorage:WaitForChild("MaterialDesign3"))

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MD3Demo"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local theme = MD3.Theme.Default()

-- Root layout: app bar on top, scrolling content, nav bar on bottom.
local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = theme.Colors.Background
root.BorderSizePixel = 0
root.Parent = screenGui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.Parent = root

-- Swap this for your own uploaded icon (rbxassetid://...); left blank here
-- so the demo doesn't depend on guessing a real asset id.
local darkModeIcon = ""

local appBar = MD3.TopAppBar.new({
	Title = "Material You Demo",
	Actions = {
		{
			Icon = darkModeIcon,
			OnActivated = function()
				theme:Toggle()
			end,
		},
	},
	Parent = root,
})
appBar.Instance.LayoutOrder = 0

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Content"
scroll.Size = UDim2.new(1, 0, 1, -64 - 80)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new()
scroll.ScrollBarThickness = 6
scroll.LayoutOrder = 1
scroll.Parent = root

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingTop = UDim.new(0, 16)
contentPadding.PaddingBottom = UDim.new(0, 16)
contentPadding.PaddingLeft = UDim.new(0, 16)
contentPadding.PaddingRight = UDim.new(0, 16)
contentPadding.Parent = scroll

local contentLayout = Instance.new("UIListLayout")
contentLayout.FillDirection = Enum.FillDirection.Vertical
contentLayout.Padding = UDim.new(0, 16)
contentLayout.Parent = scroll

--== Buttons card ==--
local buttonsCard = MD3.Card.new({ Variant = "Elevated", Size = UDim2.new(1, 0, 0, 0), Parent = scroll })
buttonsCard.Instance.AutomaticSize = Enum.AutomaticSize.Y
buttonsCard.Instance.LayoutOrder = 1

local buttonsRow = Instance.new("Frame")
buttonsRow.BackgroundTransparency = 1
buttonsRow.AutomaticSize = Enum.AutomaticSize.Y
buttonsRow.Size = UDim2.new(1, 0, 0, 0)
buttonsRow.Parent = buttonsCard.Instance
local buttonsRowLayout = Instance.new("UIListLayout")
buttonsRowLayout.FillDirection = Enum.FillDirection.Horizontal
buttonsRowLayout.Wraps = true
buttonsRowLayout.Padding = UDim.new(0, 8)
buttonsRowLayout.Parent = buttonsRow

for _, variant in { "Filled", "Tonal", "Outlined", "Text", "Elevated" } do
	MD3.Button.new({ Text = variant, Variant = variant, Parent = buttonsRow })
end

--== Selection controls card ==--
local selectionCard = MD3.Card.new({ Variant = "Filled", Size = UDim2.new(1, 0, 0, 0), Parent = scroll })
selectionCard.Instance.AutomaticSize = Enum.AutomaticSize.Y
selectionCard.Instance.LayoutOrder = 2

local function labeledRow(text, control, parent)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.Size = UDim2.new(1, 0, 0, 0)
	row.Parent = parent
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.Padding = UDim.new(0, 8)
	rowLayout.Parent = row

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.new(0, 0, 0, 24)
	label.Text = text
	label.TextColor3 = theme.Colors.OnSurface
	MD3.Typography.Apply(label, "BodyLarge")
	label.Parent = row

	control.Instance.Parent = row
	return row
end

labeledRow("Enable notifications", MD3.Switch.new({ Value = true }), selectionCard.Instance)
labeledRow("Accept terms", MD3.Checkbox.new({ Value = false }), selectionCard.Instance)

local radioGroup = MD3.RadioButton.Group(
	{ { Value = "light", Text = "Light" }, { Value = "dark", Text = "Dark" }, { Value = "system", Text = "System" } },
	"system",
	selectionCard.Instance,
	theme
)
radioGroup.Changed:Connect(function(value)
	if value == "dark" then
		theme:SetMode("Dark")
	elseif value == "light" then
		theme:SetMode("Light")
	end
end)

local volumeSlider = MD3.Slider.new({ Min = 0, Max = 100, Value = 60, Step = 1, Parent = selectionCard.Instance })
volumeSlider.Changed:Connect(function(value)
	print("Volume:", value)
end)

--== Text field card ==--
local formCard = MD3.Card.new({ Variant = "Outlined", Size = UDim2.new(1, 0, 0, 0), Parent = scroll })
formCard.Instance.AutomaticSize = Enum.AutomaticSize.Y
formCard.Instance.LayoutOrder = 3

MD3.TextField.new({ Label = "Display name", Variant = "Outlined", Parent = formCard.Instance })
MD3.TextField.new({ Label = "Bio", Variant = "Filled", SupportingText = "Shown on your profile", Parent = formCard.Instance })

--== Chips row ==--
local chipsRow = Instance.new("Frame")
chipsRow.BackgroundTransparency = 1
chipsRow.AutomaticSize = Enum.AutomaticSize.Y
chipsRow.Size = UDim2.new(1, 0, 0, 0)
chipsRow.LayoutOrder = 4
chipsRow.Parent = scroll
local chipsLayout = Instance.new("UIListLayout")
chipsLayout.FillDirection = Enum.FillDirection.Horizontal
chipsLayout.Padding = UDim.new(0, 8)
chipsLayout.Parent = chipsRow

for _, tag in { "Action", "Adventure", "RPG", "Sandbox" } do
	MD3.Chip.new({ Text = tag, Variant = "Filter", Parent = chipsRow })
end

--== Progress indicators ==--
local progressRow = Instance.new("Frame")
progressRow.BackgroundTransparency = 1
progressRow.AutomaticSize = Enum.AutomaticSize.Y
progressRow.Size = UDim2.new(1, 0, 0, 0)
progressRow.LayoutOrder = 5
progressRow.Parent = scroll
local progressLayout = Instance.new("UIListLayout")
progressLayout.Padding = UDim.new(0, 12)
progressLayout.Parent = progressRow

MD3.ProgressIndicator.Linear({ Value = 0.65, Parent = progressRow })
MD3.ProgressIndicator.Circular({ Indeterminate = true, Parent = progressRow })

--== Dialog + Snackbar triggers ==--
local snackbar = MD3.Snackbar.new({ Parent = screenGui })

local dialog = MD3.Dialog.new({
	Parent = screenGui,
	Title = "Delete item?",
	Text = "This action cannot be undone.",
	Actions = {
		{ Text = "Cancel", Variant = "Text" },
		{
			Text = "Delete",
			Variant = "Filled",
			OnActivated = function()
				snackbar:Show("Item deleted", { Text = "Undo" })
			end,
		},
	},
})

local dialogTrigger = MD3.Button.new({ Text = "Open dialog", Variant = "Outlined", LayoutOrder = 6, Parent = scroll })
dialogTrigger.Activated:Connect(function()
	dialog:Show()
end)

--== Bottom navigation ==--
local navBar = MD3.NavigationBar.new({
	Destinations = {
		{ Icon = darkModeIcon, Label = "Home" },
		{ Icon = darkModeIcon, Label = "Search" },
		{ Icon = darkModeIcon, Label = "Profile" },
	},
	Selected = 1,
	Parent = root,
})
navBar.Instance.LayoutOrder = 2

--== Floating action button ==--
local fab = MD3.FAB.new({ Icon = darkModeIcon, Size = "Standard", Parent = screenGui })
fab.Instance.AnchorPoint = Vector2.new(1, 1)
fab.Instance.Position = UDim2.new(1, -16, 1, -96)
fab.Activated:Connect(function()
	snackbar:Show("FAB pressed")
end)
