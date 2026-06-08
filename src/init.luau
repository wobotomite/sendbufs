local client = require(script["init-modules"].client)
local server = require(script["init-modules"].server)

return table.freeze({
	create_client = client,
	create_server = server,
})
