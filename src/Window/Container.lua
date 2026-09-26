-- Mixin giving Tabs and Sections the same element API:
--   AddButton / AddToggle / AddSlider / AddInput / AddDropdown / AddKeybind /
--   AddColorPicker / AddLabel / AddParagraph / AddDivider
-- Each also has a Create* alias (CreateToggle, ...) for scripts written
-- against other executor UI libraries.
local Elements = script.Parent.Elements
local Text = require(Elements.Text)

local BUILDERS = {
	Button = require(Elements.Button),
	Toggle = require(Elements.Toggle),
	Slider = require(Elements.Slider),
	Input = require(Elements.Input),
	Dropdown = require(Elements.Dropdown),
	Keybind = require(Elements.Keybind),
	ColorPicker = require(Elements.ColorPicker),
	Label = Text.Label,
	Paragraph = Text.Paragraph,
	Divider = Text.Divider,
}

local ALIASES = {
	Textbox = "Input",
	TextBox = "Input",
	Bind = "Keybind",
	Colorpicker = "ColorPicker",
}

local Container = {}

function Container.extend(class)
	for name, builder in BUILDERS do
		local function add(self, props)
			props = props or {}
			local element = builder(self, props)
			table.insert(self._elements, element)

			local window = self._window or (self._tab and self._tab._window)
			local elementName = props.Title or props.Text or props.Name
			if window and window._registerSearchable and elementName and elementName ~= "" and name ~= "Divider" then
				local tab = self._tab or self
				local subTab = self._subTab
				local pathParts = { tab.Title or "Tab" }
				if subTab then
					table.insert(pathParts, subTab)
				end
				if self.Title and self.Title ~= "" and self ~= tab then
					table.insert(pathParts, self.Title)
				end
				table.insert(pathParts, elementName)

				window:_registerSearchable({
					name = elementName,
					path = table.concat(pathParts, " > "),
					tab = tab,
					subTab = subTab,
					target = element.Instance,
				})
			end

			return element
		end
		class["Add" .. name] = add
		class["Create" .. name] = add
	end
	for alias, target in ALIASES do
		class["Add" .. alias] = class["Add" .. target]
		class["Create" .. alias] = class["Add" .. target]
	end

	function class:_nextOrder()
		self._order += 1
		return self._order
	end
end

return Container
