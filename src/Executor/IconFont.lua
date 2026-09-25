--[[
	Loads Google's Material Icons font at runtime on executors, so real
	Material glyphs render without uploading a Font asset first.

	Styles (all Apache-2.0, google/material-design-icons):
		"Outlined" (default — the M3 look), "Filled", "Round", "Sharp"

	Downloads the style's .ttf once into the executor workspace, wraps it in
	a Roblox font-family JSON, and loads that through getcustomasset. Google
	only ships Outlined/Round/Sharp as .otf, so those come from this repo's
	assets/fonts/ (converted to TrueType by tools/convert_icon_fonts.py);
	Filled comes straight from Google. If a non-Filled style can't be loaded
	it falls back to Filled. Needs writefile/readfile + getcustomasset;
	returns nil (leaving the BuilderIcons / plain-glyph fallbacks in place)
	when the executor lacks them.

	local font = MD3.IconFont.Load()             -- Outlined; also calls MD3.Icons.SetFont(font)
	local font = MD3.IconFont.Load("MD3", "Round")
]]
local HttpService = game:GetService("HttpService")

local Root = script.Parent.Parent
local Env = require(Root.Executor.Env)
local Icons = require(Root.Core.Icons)

local IconFont = {}

local REPO_FONTS = "https://raw.githubusercontent.com/engnyg/Material-Design-3-Roblox-lua-ui/main/assets/fonts/"

IconFont.DefaultStyle = "Outlined"
IconFont.Styles = {
	Filled = {
		file = "MaterialIcons-Regular.ttf",
		url = "https://raw.githubusercontent.com/google/material-design-icons/master/font/MaterialIcons-Regular.ttf",
	},
	Outlined = { file = "MaterialIconsOutlined-Regular.ttf", url = REPO_FONTS .. "MaterialIconsOutlined-Regular.ttf" },
	Round = { file = "MaterialIconsRound-Regular.ttf", url = REPO_FONTS .. "MaterialIconsRound-Regular.ttf" },
	Sharp = { file = "MaterialIconsSharp-Regular.ttf", url = REPO_FONTS .. "MaterialIconsSharp-Regular.ttf" },
}
-- Kept for backwards compatibility: the Filled font URL.
IconFont.Url = IconFont.Styles.Filled.url

local loaded: { [string]: Font } = {}

local function loadStyle(folder: string, style: string): (Font?, string?)
	local spec = IconFont.Styles[style]
	Env.MakeFolder(folder)
	local ttfPath = `{folder}/{spec.file}`
	local familyPath = `{folder}/MaterialIcons{style}.json`

	if not Env.IsFile(ttfPath) then
		local data = Env.HttpGet(spec.url)
		-- The real fonts are 350-500 KB; anything tiny is an error page.
		if not data or #data < 10000 then
			return nil, `could not download the {style} icon font`
		end
		if not Env.WriteFile(ttfPath, data) then
			return nil, "could not write the icon font"
		end
	end

	local ttfAsset = Env.GetCustomAsset(ttfPath)
	if not ttfAsset then
		return nil, "getcustomasset failed for the icon font"
	end

	-- The asset id getcustomasset hands out can change between sessions, so
	-- the family file is rewritten every time.
	local family = HttpService:JSONEncode({
		name = `MaterialIcons{style}`,
		faces = { { name = "Regular", weight = 400, style = "normal", assetId = ttfAsset } },
	})
	if not Env.WriteFile(familyPath, family) then
		return nil, "could not write the font family file"
	end
	local familyAsset = Env.GetCustomAsset(familyPath)
	if not familyAsset then
		return nil, "getcustomasset failed for the font family"
	end

	local ok, font = pcall(Font.new, familyAsset, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	if not ok then
		return nil, tostring(font)
	end
	return font
end

function IconFont.Load(folder: string?, style: string?): (Font?, string?)
	folder = folder or "MD3"
	style = style or IconFont.DefaultStyle
	if loaded[style] then
		Icons.SetFont(loaded[style])
		return loaded[style]
	end
	if not IconFont.Styles[style] then
		return nil, `unknown icon style "{style}" (use Outlined, Filled, Round or Sharp)`
	end
	if not Env.CanUseCustomAssets then
		return nil, "executor has no writefile/getcustomasset"
	end

	local font, err = loadStyle(folder, style)
	if not font and style ~= "Filled" then
		local fallback = loadStyle(folder, "Filled")
		if fallback then
			warn(`[MD3] {err}; using the Filled icon style instead`)
			font, err, style = fallback, nil, "Filled"
		end
	end
	if not font then
		return nil, err
	end

	loaded[style] = font
	Icons.SetFont(font)
	return font
end

return IconFont
