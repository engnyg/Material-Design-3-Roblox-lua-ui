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
	-- Snapshot first: task.spawn runs handlers immediately, and a handler that
	-- connects, disconnects or calls DisconnectAll (e.g. Dialog.Dismissed ->
	-- Destroy) would otherwise break pairs() with "invalid key to 'next'".
	local snapshot = {}
	for connection, fn in pairs(self._handlers) do
		snapshot[#snapshot + 1] = connection
		snapshot[#snapshot + 1] = fn
	end
	for i = 1, #snapshot, 2 do
		if snapshot[i]._connected then
			task.spawn(snapshot[i + 1], ...)
		end
	end
end

function Signal:DisconnectAll()
	for connection in pairs(self._handlers) do
		connection._connected = false
	end
	table.clear(self._handlers)
end

return Signal
