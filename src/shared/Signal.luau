--!strict
-- Minimal signal for module-to-module events (no BindableEvent, so tables pass by reference).

export type Connection = {
	Disconnect: (self: Connection) -> (),
}

export type Signal = {
	Connect: (self: Signal, callback: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
}

local Signal = {}

function Signal.new(): Signal
	local callbacks: { (...any) -> () } = {}
	local signal = {}

	function signal.Connect(_self: Signal, callback: (...any) -> ()): Connection
		table.insert(callbacks, callback)
		local connection = {}
		function connection.Disconnect(_connection: Connection)
			local index = table.find(callbacks, callback)
			if index then
				table.remove(callbacks, index)
			end
		end
		return connection :: any
	end

	function signal.Fire(_self: Signal, ...: any)
		for _, callback in table.clone(callbacks) do
			task.spawn(callback, ...)
		end
	end

	return signal :: any
end

return Signal
