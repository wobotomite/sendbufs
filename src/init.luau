local middleware = require(script.features.middleware)
local schema = require(script.features.schema)
local client = require(script["init-modules"].client)
local server = require(script["init-modules"].server)
local shared = require(script["init-modules"].shared)

return table.freeze({
	create_client = client,
	create_server = server,
	event = shared.event,
	fn = shared.fn,
	middleware = middleware.middleware,
	schema = schema,
})
