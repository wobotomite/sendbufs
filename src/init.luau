local middleware = require(script.features.middleware)
local schema = require(script.features.schema)
local libtypes = require(script.util.libtypes)
local client = require(script["init-modules"].client)
local server = require(script["init-modules"].server)
local shared = require(script["init-modules"].shared)

export type ClientEvent<T> = libtypes.ClientRemote<T>
export type ServerEvent<T> = libtypes.ServerRemote<T>

export type ClientFunction<T = nil, O = nil> = libtypes.ClientFunction<T, O>
export type ServerFunction<T = nil, O = nil> = libtypes.ServerFunction<T, O>

export type Middleware = libtypes.Middleware
export type Callback = libtypes.Callback
export type Schema<T> = libtypes.Schema<T>

return table.freeze({
	create_client = client,
	create_server = server,
	event = shared.event,
	unreliable = shared.unreliable,
	fn = shared.fn,
	middleware = middleware.middleware,
	schema = schema,
})
