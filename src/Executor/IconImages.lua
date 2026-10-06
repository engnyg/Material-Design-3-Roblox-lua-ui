--[[
	Loads the Material icons as images (sprite sheets) on executors, the
	same way NeverLose loads its images: HttpGet the PNG, writefile it into
	the workspace, then getcustomasset. Images load reliably on executors
	where fonts built from getcustomasset files don't.

	Each style is a set of pages (assets/icons/<Style>/<page>.png in this
	repo, rendered from Google's fonts by tools/build_icon_sheets.py):
		"Outlined" (default — the M3 look), "Filled", "Round", "Sharp"
	Load() fetches page 0, which has every icon the library draws itself;
	the other pages download the first time one of their icons is shown.

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
local IconSheet = require(Root.Core.IconSheet)

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
local loaded: { [string]: { [number]: string } } = {} -- style -> page -> content id

local function pageUrl(style: string, page: number): string
	return `{IconImages.BaseUrl}{style}/{page}.png`
end

-- The workspace file a page is cached in; the layout version keeps pages
-- of an older layout (or the old single-sheet files) from being reused.
local function fileName(style: string, page: number): string
	return `MaterialIcons{IconSheet.Version}-{style}-{page}.png`
end

-- Downloads (once) and returns the content id for a page of a style.
local function fetch(style: string, page: number): (string?, string?)
	local name = fileName(style, page)
	local path = `{Assets.Folder}/{name}`
	-- A file left over from a failed download would otherwise be reused
	-- forever, so check it really is a PNG.
	local existing = Env.ReadFile(path)
	if existing and existing:sub(1, 4) ~= PNG_SIGNATURE then
		Env.DeleteFile(path)
	end

	local url = pageUrl(style, page)
	local asset, err = Assets.FromUrl(url, name)
	if not asset then
		return nil, err
	end
	local data = Env.ReadFile(path)
	if data and data:sub(1, 4) ~= PNG_SIGNATURE then
		Env.DeleteFile(path)
		Assets.Forget(url)
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

-- A style's page, downloaded and checked once (nil + reason on failure).
-- Yields.
local function loadPage(style: string, page: number): (string?, string?)
	local pages = loaded[style]
	if pages and pages[page] then
		return pages[page]
	end
	local asset, err = fetch(style, page)
	if not asset then
		return nil, err
	end
	if not verify(asset) then
		return nil, `Roblox could not load the {style} icon sheet`
	end
	loaded[style] = loaded[style] or {}
	loaded[style][page] = asset
	return asset
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

	local asset, err = loadPage(style, 0)
	if not asset then
		return false, err
	end

	IconImages.CurrentStyle = style
	Icons.SetSheet(asset, function(page)
		local image, pageErr = loadPage(style, page)
		if not image then
			warn(`[MD3] could not load {style} icon page {page}: {pageErr}`)
		end
		return image
	end)
	return true
end

-- Stops using the sprite sheet (back to font / BuilderIcons / symbols).
function IconImages.Unload()
	IconImages.CurrentStyle = nil
	Icons.SetSheet(nil)
end

return IconImages
