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

-- What a file is, from its first bytes: "png" | "jpg" | "webm" | "gif" |
-- "webp" | "html", or nil when unknown.
function Assets.Sniff(data: string): string?
	if data:sub(1, 4) == "\137PNG" then
		return "png"
	elseif data:sub(1, 3) == "\255\216\255" then
		return "jpg"
	elseif data:sub(1, 4) == "\26\69\223\163" then
		return "webm"
	elseif data:sub(1, 4) == "GIF8" then
		return "gif"
	elseif data:sub(1, 4) == "RIFF" and data:sub(9, 12) == "WEBP" then
		return "webp"
	elseif looksLikeHtml(data) then
		return "html"
	end
	return nil
end

-- Why `data` can't be used as `want` ("image" or "video"), or nil when it
-- can. Unknown formats are let through as images (Roblox also reads BMP /
-- TGA); a video must really be WebM. The second result is true when the
-- file is no use for anything (so a cached copy can be deleted), false when
-- it is just the wrong kind for this request.
local function unusable(data: string, want: string): (string?, boolean)
	local kind = Assets.Sniff(data)
	if kind == "html" then
		return "the link returned a web page, not the file (use a direct download link, e.g. raw.githubusercontent.com)", true
	elseif kind == "gif" then
		return "GIF isn't supported by Roblox (it can't play or even show it); use PNG / JPG for a still image, or convert it to WebM for a video background", true
	elseif kind == "webp" then
		return "WebP isn't supported by Roblox; use PNG or JPG", true
	elseif want == "image" and kind == "webm" then
		return "that's a WebM video, not an image"
	elseif want == "video" and kind ~= "webm" then
		return "a video background has to be a WebM file"
	end
	return nil
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

-- Downloads `url` (once) into the workspace and returns a content id for it,
-- or nil and the reason. `want` is "image" (default) or "video"; the file is
-- checked for a format Roblox can actually use either way.
function Assets.FromUrl(url: string, fileName: string?, want: string?): (string?, string?)
	want = want or "image"
	local key = `{want}:{url}`
	if cache[key] then
		return cache[key]
	end
	if not Env.CanUseCustomAssets then
		return nil, "this executor has no writefile / getcustomasset"
	end

	Env.MakeFolder(Assets.Folder)
	local path = `{Assets.Folder}/{fileName or fileNameFor(url)}`
	local data = Env.ReadFile(path)
	if data then
		-- Downloaded before, possibly before these checks existed.
		local problem, useless = unusable(data, want)
		if problem then
			if useless then
				Env.DeleteFile(path) -- so a fixed file at the same URL is fetched again
			end
			return nil, problem
		end
	else
		data = Env.HttpGet(url)
		if not data or #data == 0 then
			return nil, `could not download {url}`
		end
		local problem = unusable(data, want)
		if problem then
			return nil, problem
		end
		if not Env.WriteFile(path, data) then
			return nil, `could not write {path}`
		end
	end

	local asset = Env.GetCustomAsset(path)
	if not asset then
		return nil, `getcustomasset failed for {path}`
	end
	cache[key] = asset
	return asset
end

-- Drops a cached URL/file so the next request loads it again.
function Assets.Forget(key: string)
	for _, want in { "image", "video" } do
		cache[`{want}:{key}`] = nil
	end
end

-- Returns a workspace file as a content id, or nil and the reason.
function Assets.FromFile(path: string, want: string?): (string?, string?)
	want = want or "image"
	local key = `{want}:{path}`
	if cache[key] then
		return cache[key]
	end
	local data = Env.ReadFile(path)
	if not data then
		return nil, `no file {path} in the workspace`
	end
	local problem = unusable(data, want)
	if problem then
		return nil, problem
	end
	local asset = Env.GetCustomAsset(path)
	if not asset then
		return nil, `getcustomasset failed for {path}`
	end
	cache[key] = asset
	return asset
end

-- Like Resolve, but returns "" plus the reason instead of warning.
-- `want` is "image" (default) or "video".
function Assets.ResolveWithReason(source, want: string?): (string, string?)
	if source == nil or source == "" then
		return "", "no image given"
	end
	if type(source) == "number" or (type(source) == "string" and source:match("^%d+$")) then
		return `rbxassetid://{source}`
	end
	if type(source) ~= "string" then
		return "", `not an image: {tostring(source)}`
	end
	if source:match("^rbx") or source:match("^http://www%.roblox%.com/asset") then
		return source
	end
	local ok, asset, problem
	if source:match("^https?://") then
		ok, asset, problem = pcall(Assets.FromUrl, source, nil, want)
	else
		ok, asset, problem = pcall(Assets.FromFile, source, want)
	end
	if not ok then
		return "", tostring(asset)
	end
	return asset or "", if asset then nil else (problem or `could not load {source}`)
end

-- Turns any supported image reference into something ImageLabel.Image
-- accepts. Never throws; returns "" (and warns) when the image can't be loaded.
function Assets.Resolve(image): string
	if image == nil or image == "" then
		return ""
	end
	local asset, problem = Assets.ResolveWithReason(image, "image")
	if asset == "" then
		warn(`[MD3] could not load image {image}: {problem}`)
	end
	return asset
end

-- Downloads several images up front (e.g. at script start) so later
-- Resolve calls don't wait on the network.
function Assets.Preload(urls: { string })
	for _, url in urls do
		task.spawn(function()
			pcall(Assets.FromUrl, url, nil, if url:lower():gsub("[?#].*$", ""):match("%.webm$") then "video" else "image")
		end)
	end
end

return Assets
