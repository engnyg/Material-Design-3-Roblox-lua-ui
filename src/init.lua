--[[
	MD3 — a Material Design 3 UI library for Roblox Luau.

	Quick start:
		local MD3 = require(path.to.MaterialDesign3)

		-- optional: recolor the whole app from one seed color (mutates the
		-- shared default theme, so every already-built component updates live)
		MD3.Theme.Default():SetSeedColor(Color3.fromHex("#006C51"))
		MD3.Theme.Default():SetMode("Dark")

		local button = MD3.Button.new({ Text = "Continue", Parent = someFrame })
		button.Activated:Connect(function() print("clicked") end)

	See example/init.client.lua for a fuller demo.
]]
local MD3 = {}

-- Core
MD3.Theme = require(script.Core.Theme)
MD3.Typography = require(script.Core.Typography)
MD3.Shape = require(script.Core.Shape)
MD3.Motion = require(script.Core.Motion)
MD3.Elevation = require(script.Core.Elevation)
MD3.StateLayer = require(script.Core.StateLayer)
MD3.Ripple = require(script.Core.Ripple)
MD3.Icons = require(script.Core.Icons)

-- Utilities (exposed in case consumers want to build custom components the same way)
MD3.Color = require(script.Util.Color)
MD3.Signal = require(script.Util.Signal)
MD3.Maid = require(script.Util.Maid)
MD3.Create = require(script.Util.Create)

-- Components
MD3.Button = require(script.Components.Button)
MD3.IconButton = require(script.Components.IconButton)
MD3.FAB = require(script.Components.FAB)
MD3.Card = require(script.Components.Card)
MD3.Switch = require(script.Components.Switch)
MD3.Checkbox = require(script.Components.Checkbox)
MD3.RadioButton = require(script.Components.RadioButton)
MD3.Slider = require(script.Components.Slider)
MD3.TextField = require(script.Components.TextField)
MD3.Chip = require(script.Components.Chip)
MD3.Dialog = require(script.Components.Dialog)
MD3.Snackbar = require(script.Components.Snackbar)
MD3.TopAppBar = require(script.Components.TopAppBar)
MD3.NavigationBar = require(script.Components.NavigationBar)
MD3.ProgressIndicator = require(script.Components.ProgressIndicator)
MD3.Divider = require(script.Components.Divider)

-- Shorthand for MD3.Theme.new(seed, mode)
function MD3.new(seed: Color3?, mode: string?)
	return MD3.Theme.new(seed, mode)
end

return MD3
