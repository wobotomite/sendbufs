local RunService = game:GetService("RunService")

local libtypes = require(script.Parent.Parent.util.libtypes)

local middleware_map: { [number]: { libtypes.Middleware } } = {}

function middleware(t: libtypes.Intermediate<any, any, any>, mw: libtypes.Middleware)
	local entry = middleware_map[t.id] or {}
	table.insert(entry, mw)
	middleware_map[t.id] = entry
end
function get(id: number): { libtypes.Middleware }?
	return middleware_map[id]
end

function run_middleware(id: number, plr: Player)
	assert(RunService:IsServer(), "Middleware can only be called on the server!")
	local mw = (get(id) or {}) :: { libtypes.Middleware }
	for i, v in mw do
		if not v(id, plr) then
			return false
		end
	end
	return true
end

return table.freeze({
	run_middleware = run_middleware,
	middleware = middleware,
	get = get,
})
