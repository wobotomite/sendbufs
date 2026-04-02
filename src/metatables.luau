local Players = game:GetService("Players")

local client_lifecycle = require("./client-lifecycle")
local server_lifecycle = require("./server-lifecycle")

local types = require("./types")

local constants = require("./constants")

local client_remote_metatable = {}
client_remote_metatable.__index = client_remote_metatable
local server_remote_metatable = {}
server_remote_metatable.__index = server_remote_metatable
local server_function_metatable = {}
server_function_metatable.__index = server_function_metatable
local client_function_metatable = {}
client_function_metatable.__index = client_function_metatable

type t_event<T> = types.t_event<T>
type t_fn<T, R> = types.t_fn<T, R>

@native
function connect_listener(listeners: { types.fn_listener }, fn: (...any) -> (), once: boolean?)
	local t = { fn = fn, once = once }
	table.insert(listeners, t)
	return function()
		local i = table.find(listeners, t)
		if i ~= nil then
			table.remove(listeners, i)
		end
	end
end

@native
function wait<T>(self: t_event<T>): (T, Player?)
	local coro = coroutine.running()
	local data, plr
	connect_listener(self.listeners, function(...)
		data, plr = ...
		task.defer(coro)
	end, true)
	coroutine.yield()

	return data, plr
end
@native
function connect<T>(self: t_event<T>, callback: (T) -> (), once: boolean?)
	return connect_listener(self.listeners, callback, once)
end

@native
function to_player_table(t: Player | { Player }): { Player }
	if typeof(t) == "table" then
		return t
	end
	return { t }
end

--@client only!
@native
function client_remote_metatable.fire_server<T>(self: t_event<T>, arg: T)
	local write_fn = self.schema.write
	local fn = if self.type == constants.EVENT_TYPE.RELIABLE
		then client_lifecycle.send_reliable_packet
		else client_lifecycle.send_unreliable_packet;
	(fn :: never)(self.id, write_fn, arg)
end
client_remote_metatable.wait = wait
client_remote_metatable.connect = connect

table.freeze(client_remote_metatable)

@native
function client_function_metatable.invoke<T, R>(self: t_fn<T, R>, arg: T): (boolean, R)
	local write_fn = self.schema.write
	local read_fn = self.schema_out.read
	return client_lifecycle.invoke_request(self.id, write_fn, read_fn, arg)
end

table.freeze(client_function_metatable)

-- server only!
@native
function server_remote_metatable.fire_client<T>(self: t_event<T>, plr: Player | { Player }, arg: T): ()
	local plr = to_player_table(plr)
	local write_fn = self.schema.write
	local fn = if self.type == constants.EVENT_TYPE.RELIABLE
		then server_lifecycle.send_reliable_packet
		else server_lifecycle.send_reliable_packet
	for i = 1, #plr do
		(fn :: never)(plr[i], self.id, write_fn, arg)
	end
end
@native
function server_remote_metatable.fire_all<T>(self: t_event<T>, arg: T): ()
	local plr = Players:GetPlayers()
	local write_fn = self.schema.write
	local fn = if self.type == constants.EVENT_TYPE.RELIABLE
		then server_lifecycle.send_reliable_packet
		else server_lifecycle.send_reliable_packet
	for i = 1, #plr do
		(fn :: never)(plr[i], self.id, write_fn, arg)
	end
end
server_remote_metatable.wait = wait
server_remote_metatable.connect = connect
table.freeze(server_remote_metatable)

@native
function server_function_metatable.set_callback<T, R>(self: t_fn<T, R>, cb: (arg: T, plr: Player?) -> R)
	if self.callback then
		error("CALLBACK FN ALREADY EXISTS!")
	end
	self.callback = cb
end

table.freeze(server_function_metatable)

return table.freeze({
	client_remote_metatable = client_remote_metatable,
	client_function_metatable = client_function_metatable,
	server_remote_metatable = server_remote_metatable,
	server_function_metatable = server_function_metatable,
})
