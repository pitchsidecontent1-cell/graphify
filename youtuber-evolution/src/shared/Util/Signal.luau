--!strict
-- Tiny signal implementation (no BindableEvents, works in Lune too).

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal = {
	Connect: (self: Signal, fn: (...any) -> ()) -> Connection,
	Once: (self: Signal, fn: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
	DisconnectAll: (self: Signal) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new(): Signal
	local self = setmetatable({ _handlers = {} :: { any } }, Signal)
	return (self :: any) :: Signal
end

function Signal.Connect(self: any, fn: (...any) -> ()): Connection
	local handler = { fn = fn, Connected = true }
	table.insert(self._handlers, handler)
	local connection = {
		Connected = true,
	}
	function connection.Disconnect(conn: any)
		conn.Connected = false
		handler.Connected = false
		local idx = table.find(self._handlers, handler)
		if idx then
			table.remove(self._handlers, idx)
		end
	end
	return (connection :: any) :: Connection
end

function Signal.Once(self: any, fn: (...any) -> ()): Connection
	local conn: Connection
	conn = Signal.Connect(self, function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

-- Each handler runs in its own thread, so one yielding (or erroring)
-- handler never blocks the others.
function Signal.Fire(self: any, ...: any)
	local handlers: { any } = table.clone(self._handlers :: { any })
	for _, handler in handlers do
		if handler.Connected then
			task.spawn(handler.fn, ...)
		end
	end
end

function Signal.DisconnectAll(self: any)
	for _, handler in self._handlers do
		handler.Connected = false
	end
	table.clear(self._handlers)
end

return Signal
