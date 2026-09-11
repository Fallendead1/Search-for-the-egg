--!strict
-- Minimal event bus used only for client-internal UI coordination
-- (controllers talking to each other). Not a substitute for RemoteEvents.

local Signal = {}
Signal.__index = Signal

export type Signal = typeof(setmetatable(
	{} :: { _handlers: { (...any) -> () } },
	Signal
))

function Signal.new(): Signal
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal.Connect(self: Signal, handler: (...any) -> ()): () -> ()
	table.insert(self._handlers, handler)
	local connected = true
	return function()
		if not connected then
			return
		end
		connected = false
		local index = table.find(self._handlers, handler)
		if index then
			table.remove(self._handlers, index)
		end
	end
end

function Signal.Fire(self: Signal, ...: any)
	for _, handler in ipairs(table.clone(self._handlers)) do
		task.spawn(handler, ...)
	end
end

return Signal
