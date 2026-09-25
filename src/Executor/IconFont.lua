--[[
	Loads Google's Material Icons font at runtime on executors, so real
	Material glyphs render without uploading a Font asset first.

	Downloads MaterialIcons-Regular.ttf (Apache-2.0, google/material-design-icons)
	once into the executor workspace, wraps it in a Roblox font-family JSON,
	and loads that through getcustomasset. Needs writefile/readfile +
	getcustomasset; returns nil (and leaves the plain-glyph fallbacks in
	place) when the executor lacks them.

	local font = MD3.IconFont.Load()   -- also calls MD3.Icons.SetFont(font)
]]
local HttpService = game:GetService("HttpService")

local Root = script.Parent.Parent
local Env = require(Root.Executor.Env)
local Icons = require(Root.Core.Icons)

local IconFont = {}

IconFont.Url = "https://raw.githubusercontent.com/google/material-design-icons/master/font/MaterialIcons-Regular.ttf"

local loaded: Font? = nil

function IconFont.Load(folder: string?): (Font?, string?)
	if loaded then
		return loaded
	end
	if not Env.CanUseCustomAssets then
		return nil, "executor has no writefile/getcustomasset"
	end

	folder = folder or "MD3"
	Env.MakeFolder(folder)
	local ttfPath = `{folder}/MaterialIcons-Regular.ttf`
	local familyPath = `{folder}/MaterialIcons.json`

	if not Env.IsFile(ttfPath) then
		local data = Env.HttpGet(IconFont.Url)
		-- The real font is ~350 KB; anything tiny is an error page.
		if not data or #data < 10000 then
			return nil, "could not download the icon font"
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
		name = "MaterialIcons",
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

	loaded = font
	Icons.SetFont(font)
	return font
end

return IconFont
