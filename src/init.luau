local RunService = game:GetService("RunService")

local serdes = require("@self/serdes")

local is_server = RunService:IsServer()

local server = require("@self/server-lifecycle")
local client = require("@self/client-lifecycle")
local remotes = require("@self/remotes")
local metatables = require("@self/metatables")
local constants = require("@self/constants")
local middleware = require("@self/middleware")
local types = require("@self/types")

export type TEvent<T = never> = types.t_event<T>
export type TFunction<T = never, R = never> = types.t_fn<T, R>
export type TReplicated<T = never, R = never> = types.t_event<T> | types.t_fn<T, R>

do
	local globalid = 0

	function take_next()
		globalid += 1
		return globalid
	end
	function add<T>(t: T): T
		remotes[globalid] = t :: never
		return t
	end
end

function create_event<T>(t: T): TEvent<T>
	return add(setmetatable({
		kind = "event",
		listeners = {},
		schema = t,
		type = constants.EVENT_TYPE.RELIABLE,
		id = take_next(),
	}, if is_server then metatables.server_remote_metatable else metatables.client_remote_metatable)) :: never
end

function create_unreliable<T>(t: T): TEvent<T>
	return add(setmetatable({
		kind = "event",
		listeners = {},
		schema = t,
		type = constants.EVENT_TYPE.UNRELIABLE,
		id = take_next(),
	}, if is_server then metatables.server_remote_metatable else metatables.client_remote_metatable) :: never)
end

function create_request<T, R>(input: T, output: R): TFunction<T, R>
	return add(setmetatable({
		callback = nil,
		kind = "function",
		schema = input,
		schema_out = output,
		id = take_next(),
	}, if is_server then metatables.server_function_metatable else metatables.client_function_metatable) :: never)
end

if is_server then
	server.start()
else
	client.start()
end

return table.freeze({
	create_event = create_event,
	create_unreliable = create_unreliable,
	create_request = create_request,
	middleware = middleware.middleware :: <T, R>(
		evt: TReplicated<T, R>,
		fn: (id: number, plr: Player, b: buffer, refs: { unknown }?) -> boolean
	) -> (),
	global_middleware = middleware.global_middleware :: (fn: (id: number, plr: Player, b: buffer, refs: { unknown }?) -> boolean) -> (),
	schema = serdes,
})
