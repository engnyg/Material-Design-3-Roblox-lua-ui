-- (De)serializes flag values to JSON for config files. JSON has no Color3
-- or EnumItem, so those are wrapped in small tagged tables.
local HttpService = game:GetService("HttpService")

local Config = {}

function Config.Serialize(value)
	local t = typeof(value)
	if t == "Color3" then
		return { __type = "Color3", hex = value:ToHex() }
	elseif t == "EnumItem" then
		return { __type = "EnumItem", enum = tostring(value.EnumType), name = value.Name }
	elseif t == "table" then
		local out = {}
		for k, v in value do
			out[k] = Config.Serialize(v)
		end
		return out
	end
	return value
end

function Config.Deserialize(value)
	if type(value) ~= "table" then
		return value
	end
	if value.__type == "Color3" then
		return Color3.fromHex(value.hex)
	elseif value.__type == "EnumItem" then
		local ok, item = pcall(function()
			return (Enum :: any)[value.enum][value.name]
		end)
		return ok and item or nil
	end
	local out = {}
	for k, v in value do
		out[k] = Config.Deserialize(v)
	end
	return out
end

-- flags: { [flagName] = element } -> JSON string of every element's value
function Config.Encode(flags): string
	local data = {}
	for flag, element in flags do
		if element.Save ~= false then
			data[flag] = Config.Serialize(element.Value)
		end
	end
	return HttpService:JSONEncode(data)
end

function Config.Decode(json: string): { [string]: any }?
	local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok or type(data) ~= "table" then
		return nil
	end
	local out = {}
	for flag, value in data do
		out[flag] = Config.Deserialize(value)
	end
	return out
end

return Config
