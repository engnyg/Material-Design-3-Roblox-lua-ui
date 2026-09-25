-- Lightweight signal implementation (avoids BindableEvent overhead).
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local handlers = self._handlers
	local connection = { _connected = true }
	handlers[connection] = fn

	function connection:Disconnect()
		if self._connected then
			self._connected = false
			handlers[self] = nil
		end
	end

	return connection
end

function Signal:Fire(...)
	for connection, fn in pairs(self._handlers) do
		if connection._connected then
			task.spawn(fn, ...)
		end
	end
end

function Signal:DisconnectAll()
	table.clear(self._handlers)
end

return Signal
