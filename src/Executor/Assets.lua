--[[
	Loads images from outside Roblox (a web URL or a file in the executor
	workspace) so they can be used anywhere an Image is expected, without
	uploading them as Roblox assets first.

	How: HttpGet the file once, writefile it into MD3/assets/, then turn it
	into a content id with getcustomasset (cached on disk and in memory).

	local image = MD3.Assets.Resolve("https://example.com/logo.png")
	imageLabel.Image = image

	Every Icon / Logo prop in MD3 goes through Assets.Resolve, so these all
	work the same:
		Icon = "https://raw.githubusercontent.com/me/repo/main/icon.png"
		Icon = "rbxassetid://1234567"   or   Icon = 1234567
		Icon = "MyHub/icon.png"         -- a file already in the workspace
	Without executor file functions, web URLs resolve to "" (no image) and
	rbxassetid ids pass through unchanged.
]]
local Root = script.Parent.Parent
local Env = require(Root.Executor.Env)

local Assets = {}

Assets.Folder = "MD3/assets"

local cache: { [string]: string } = {}

-- Short stable hash so different URLs with the same file name don't clash.
local function hash(text: string): string
	local h = 5381
	for i = 1, #text do
		h = (h * 33 + string.byte(text, i)) % 4294967296
	end
	return string.format("%08x", h)
end

local function fileNameFor(url: string): string
	local path = url:gsub("[?#].*$", "")
	local name = path:match("([^/]+)$") or "image"
	name = name:gsub("[^%w%-_%.]", "_")
	if not name:find("%.%w+$") then
		name ..= ".png"
	end
	return `{hash(url)}_{name}`
end

local function looksLikeHtml(data: string): boolean
	local head = data:sub(1, 256):lower()
	return head:find("<!doctype", 1, true) ~= nil or head:find("<html", 1, true) ~= nil
end

-- True for values that should be shown as an image rather than treated as
-- a Material icon name.
function Assets.IsImage(value): boolean
	if type(value) == "number" then
		return true
	end
	if type(value) ~= "string" or value == "" then
		return false
	end
	return value:match("^rbxasset") ~= nil
		or value:match("^rbxthumb") ~= nil
		or value:match("^rbxhttp") ~= nil
		or value:match("^https?://") ~= nil
		or value:match("%.png$") ~= nil
		or value:match("%.jpe?g$") ~= nil
		or value:match("^%d+$") ~= nil
end

-- Downloads `url` (once) into the workspace and returns a content id for it.
function Assets.FromUrl(url: string, fileName: string?): (string?, string?)
	if cache[url] then
		return cache[url]
	end
	if not Env.CanUseCustomAssets then
		return nil, "executor has no writefile/getcustomasset"
	end

	Env.MakeFolder(Assets.Folder)
	local path = `{Assets.Folder}/{fileName or fileNameFor(url)}`
	if not Env.IsFile(path) then
		local data = Env.HttpGet(url)
		if not data or #data == 0 or looksLikeHtml(data) then
			return nil, `could not download {url}`
		end
		if not Env.WriteFile(path, data) then
			return nil, `could not write {path}`
		end
	end

	local asset = Env.GetCustomAsset(path)
	if not asset then
		return nil, `getcustomasset failed for {path}`
	end
	cache[url] = asset
	return asset
end

-- Returns a workspace file as a content id.
function Assets.FromFile(path: string): string?
	if cache[path] then
		return cache[path]
	end
	if not Env.IsFile(path) then
		return nil
	end
	local asset = Env.GetCustomAsset(path)
	if asset then
		cache[path] = asset
	end
	return asset
end

-- Turns any supported image reference into something ImageLabel.Image
-- accepts. Never throws; returns "" when the image can't be loaded.
function Assets.Resolve(image): string
	if image == nil or image == "" then
		return ""
	end
	if type(image) == "number" or (type(image) == "string" and image:match("^%d+$")) then
		return `rbxassetid://{image}`
	end
	if type(image) ~= "string" then
		return ""
	end
	if image:match("^rbx") or image:match("^http://www%.roblox%.com/asset") then
		return image
	end
	if image:match("^https?://") then
		local ok, asset = pcall(Assets.FromUrl, image)
		if ok and asset then
			return asset
		end
		warn(`[MD3] could not load image {image}`)
		return ""
	end
	local ok, asset = pcall(Assets.FromFile, image)
	return ok and asset or image
end

-- Downloads several images up front (e.g. at script start) so later
-- Resolve calls don't wait on the network.
function Assets.Preload(urls: { string })
	for _, url in urls do
		task.spawn(function()
			pcall(Assets.FromUrl, url)
		end)
	end
end

return Assets
