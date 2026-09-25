--[[
	Executor environment shims. Script executors expose non-standard globals
	(gethui, writefile, getcustomasset, ...) whose names and availability
	differ per executor; everything here degrades gracefully when a function
	is missing, so the library still runs in plain Roblox Studio/LocalScripts.

	local Env = MD3.Env
	Env.GetGuiParent()          -- gethui() > CoreGui > PlayerGui
	Env.WriteFile("MyHub/a.txt", "hi")
	Env.HttpGet(url)
]]
local Players = game:GetService("Players")

local Env = {}

-- Executor globals are read through the chunk's environment; in normal
-- Roblox these are simply nil.
local gethui_ = gethui or get_hidden_gui
local protectGui = (syn and syn.protect_gui) or protect_gui or protectgui
local writefile_ = writefile
local readfile_ = readfile
local isfile_ = isfile
local isfolder_ = isfolder
local makefolder_ = makefolder
local listfiles_ = listfiles
local delfile_ = delfile
local getcustomasset_ = getcustomasset or getsynasset
local setclipboard_ = setclipboard or toclipboard or set_clipboard
local request_ = (syn and syn.request) or (http and http.request) or http_request or request
local identifyexecutor_ = identifyexecutor or getexecutorname

local function try(fn, ...)
	if type(fn) ~= "function" then
		return false, "unsupported"
	end
	return pcall(fn, ...)
end

do
	local ok, name = try(identifyexecutor_)
	Env.Name = ok and tostring(name) or nil
end
Env.IsExecutor = Env.Name ~= nil or type(getgenv) == "function"
Env.CanUseFiles = type(writefile_) == "function" and type(readfile_) == "function" and type(isfile_) == "function"
Env.CanUseCustomAssets = Env.CanUseFiles and type(getcustomasset_) == "function"

-- Shared table that survives re-executing a script (getgenv), used to find
-- and replace windows created by a previous run of the same script.
function Env.Registry(): { [any]: any }
	local ok, genv = try(getgenv)
	local root = (ok and type(genv) == "table" and genv) or shared or _G
	root.__MD3 = root.__MD3 or {}
	return root.__MD3
end

-- Best container for executor UIs: a hidden UI root when the executor has
-- one, then CoreGui (needs elevated identity), then the player's PlayerGui.
function Env.GetGuiParent(): Instance
	local ok, hui = try(gethui_)
	if ok and typeof(hui) == "Instance" then
		return hui
	end
	local coreOk, coreGui = pcall(function()
		local core = game:GetService("CoreGui")
		-- Parenting into CoreGui is what fails without elevated identity,
		-- so that's the thing to test.
		local probe = Instance.new("Folder")
		probe.Parent = core
		probe:Destroy()
		return core
	end)
	if coreOk and coreGui then
		return coreGui
	end
	local player = Players.LocalPlayer
	return player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui")
end

function Env.ProtectGui(gui: Instance)
	try(protectGui, gui)
end

-- A random, unremarkable instance name so scripts in the game can't find
-- the UI by searching for a fixed name.
function Env.RandomName(): string
	local chars = table.create(12)
	for i = 1, 12 do
		chars[i] = string.char(math.random(97, 122))
	end
	return table.concat(chars)
end

--== Files ==--

function Env.IsFile(path: string): boolean
	local ok, result = try(isfile_, path)
	return ok and result == true
end

function Env.IsFolder(path: string): boolean
	local ok, result = try(isfolder_, path)
	return ok and result == true
end

function Env.ReadFile(path: string): string?
	if not Env.IsFile(path) then
		return nil
	end
	local ok, content = try(readfile_, path)
	return ok and content or nil
end

function Env.WriteFile(path: string, content: string): boolean
	local ok = try(writefile_, path, content)
	return ok
end

function Env.DeleteFile(path: string): boolean
	local ok = try(delfile_, path)
	return ok
end

-- Creates every folder along `path` ("A/B/C").
function Env.MakeFolder(path: string)
	local current = ""
	for part in string.gmatch(path, "[^/\\]+") do
		current = current == "" and part or `{current}/{part}`
		if not Env.IsFolder(current) then
			try(makefolder_, current)
		end
	end
end

function Env.ListFiles(path: string): { string }
	local ok, files = try(listfiles_, path)
	return ok and type(files) == "table" and files or {}
end

--== Web / misc ==--

function Env.HttpGet(url: string): string?
	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)
	if ok and type(body) == "string" then
		return body
	end
	local reqOk, response = try(request_, { Url = url, Method = "GET" })
	if reqOk and type(response) == "table" and type(response.Body) == "string" then
		return response.Body
	end
	return nil
end

function Env.GetCustomAsset(path: string): string?
	local ok, asset = try(getcustomasset_, path)
	return ok and asset or nil
end

function Env.SetClipboard(text: string): boolean
	local ok = try(setclipboard_, text)
	return ok
end

return Env
