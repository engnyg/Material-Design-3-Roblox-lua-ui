-- Cleanup helper: tracks connections/instances/callbacks and disposes them together.
local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _tasks = {} }, Maid)
end

local function cleanupTask(task_)
	local t = typeof(task_)
	if t == "RBXScriptConnection" then
		task_:Disconnect()
	elseif t == "function" then
		task_()
	elseif t == "Instance" then
		task_:Destroy()
	elseif t == "table" and task_.Destroy then
		task_:Destroy()
	elseif t == "table" and task_.Disconnect then
		task_:Disconnect()
	end
end

-- Give the maid something to clean up later. Returns a key you can use with :Remove().
function Maid:GiveTask(job)
	local key = #self._tasks + 1
	self._tasks[key] = job
	return key
end

function Maid:Remove(key)
	local job = self._tasks[key]
	if job then
		cleanupTask(job)
		self._tasks[key] = nil
	end
end

function Maid:DoCleaning()
	local tasks = self._tasks
	self._tasks = {}
	for _, job in pairs(tasks) do
		cleanupTask(job)
	end
end

Maid.Destroy = Maid.DoCleaning

return Maid
