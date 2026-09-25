-- Declarative instance constructor: Create("Frame"){ Size = ..., [1] = child, ... }
local function Create(className)
	return function(props)
		local inst = Instance.new(className)
		local parent = nil

		for key, value in pairs(props) do
			if type(key) == "number" then
				value.Parent = inst
			elseif key == "Parent" then
				parent = value
			else
				inst[key] = value
			end
		end

		if parent then
			inst.Parent = parent
		end

		return inst
	end
end

return Create
