-- Material 3 Divider: a thin full-bleed or inset line.
local Root = script.Parent.Parent
local Create = require(Root.Util.Create)
local Maid = require(Root.Util.Maid)
local Theme = require(Root.Core.Theme)

local Divider = {}
Divider.__index = Divider

function Divider.new(props)
	props = props or {}
	local self = setmetatable({}, Divider)
	self._maid = Maid.new()
	self._theme = props.Theme or Theme.Default()

	local vertical = props.Vertical or false
	local size = vertical and UDim2.new(0, 1, 1, 0) or UDim2.new(1, 0, 0, 1)

	local line = Create("Frame") {
		Name = props.Name or "MD3Divider",
		BorderSizePixel = 0,
		Size = size,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	}
	self.Instance = line

	self:_applyTheme()
	self._maid:GiveTask(self._theme.Changed:Connect(function()
		self:_applyTheme()
	end))

	return self
end

function Divider:_applyTheme()
	self.Instance.BackgroundColor3 = self._theme.Colors.OutlineVariant
end

function Divider:SetTheme(theme)
	self._theme = theme
	self:_applyTheme()
end

function Divider:Destroy()
	self._maid:Destroy()
	self.Instance:Destroy()
end

return Divider
