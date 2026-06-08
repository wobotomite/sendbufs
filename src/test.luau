local schema = require(script.Parent.features.schema)
local libtypes = require(script.Parent.util.libtypes)
local client = require(script.Parent["init-modules"].client)
local server = require(script.Parent["init-modules"].server)
local shared = require(script.Parent["init-modules"].shared)

-- type ToReplaceWith<T> = {}
-- const repl: libtypes.ReplaceSchemas<typeof(network), ToReplaceWith<never>, "schema"> = nil :: never

local test_schema = schema.struct({
	s = schema.bool,
})

local network = {
	namespace1 = {
		test_evt = shared.fn(test_schema),
	},
	evt2 = shared.event(test_schema),
}

const res = server(network)
const res2 = client(network)
