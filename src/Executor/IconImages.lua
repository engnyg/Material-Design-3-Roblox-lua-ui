--[[
	Loads the Material icons as an image (sprite sheet) on executors, the
	same way NeverLose loads its images: HttpGet the PNG, writefile it into
	the workspace, then getcustomasset. Images load reliably on executors
	where fonts built from getcustomasset files don't.

	One PNG per style (assets/icons/ in this repo, rendered from the
	official Material Icons fonts by tools/build_icon_sheets.py):
		"Outlined" (default — the M3 look), "Filled", "Round", "Sharp"

	local ok, err = MD3.IconImages.Load("Round")  -- switch at any time;
	                                                -- icons on screen are redrawn
	MD3.IconImages.CurrentStyle                   -- style currently shown

	If loading fails, icons keep whatever they showed before (another
	style, Roblox's BuilderIcons or plain symbols).
]]
local ContentProvider = game:GetService("ContentProvider")

local Root = script.Parent.Parent
local Env = require(Root.Executor.Env)
local Assets = require(Root.Executor.Assets)
local Icons = require(Root.Core.Icons)

local IconImages = {}

IconImages.BaseUrl = "https://raw.githubusercontent.com/engnyg/Material-Design-3-Roblox-lua-ui/main/assets/icons/"
IconImages.DefaultStyle = "Outlined"
IconImages.StyleNames = { "Outlined", "Filled", "Round", "Sharp" }
IconImages.CurrentStyle = nil :: string?

local STYLES = {}
for _, style in IconImages.StyleNames do
	STYLES[style] = true
end

local PNG_SIGNATURE = "\137PNG"
local loaded: { [string]: string } = {}

local function fileName(style: string): string
	return `MaterialIcons{style}.png`
end

-- Downloads (once) and returns the content id for a style's sheet.
local function fetch(style: string): (string?, string?)
	local path = `{Assets.Folder}/{fileName(style)}`
	-- A file left over from a failed download would otherwise be reused
	-- forever, so check it really is a PNG.
	local existing = Env.ReadFile(path)
	if existing and existing:sub(1, 4) ~= PNG_SIGNATURE then
		Env.DeleteFile(path)
	end

	local asset, err = Assets.FromUrl(IconImages.BaseUrl .. fileName(style), fileName(style))
	if not asset then
		return nil, err
	end
	local data = Env.ReadFile(path)
	if data and data:sub(1, 4) ~= PNG_SIGNATURE then
		Env.DeleteFile(path)
		Assets.Forget(IconImages.BaseUrl .. fileName(style))
		return nil, `the downloaded {style} icon sheet is not a PNG`
	end
	return asset
end

-- Asks Roblox to load the image and reports whether it failed. Yields.
local function verify(asset: string): boolean
	local failed = false
	pcall(function()
		ContentProvider:PreloadAsync({ asset }, function(_, status)
			if status == Enum.AssetFetchStatus.Failure then
				failed = true
			end
		end)
	end)
	return not failed
end

-- Loads a style and shows it on every icon (existing ones included).
-- Returns true, or false + a reason. May yield (download + image load).
function IconImages.Load(style: string?): (boolean, string?)
	style = style or IconImages.DefaultStyle
	if not STYLES[style] then
		return false, `unknown icon style "{style}" (use Outlined, Filled, Round or Sharp)`
	end
	if not Env.CanUseCustomAssets then
		return false, "executor has no writefile/getcustomasset"
	end

	local asset = loaded[style]
	if not asset then
		local err
		asset, err = fetch(style)
		if not asset then
			return false, err
		end
		if not verify(asset) then
			return false, `Roblox could not load the {style} icon sheet`
		end
		loaded[style] = asset
	end

	IconImages.CurrentStyle = style
	Icons.SetSheet(asset)
	return true
end

-- Stops using the sprite sheet (back to font / BuilderIcons / symbols).
function IconImages.Unload()
	IconImages.CurrentStyle = nil
	Icons.SetSheet(nil)
end

return IconImages
