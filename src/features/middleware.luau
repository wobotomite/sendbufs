local libtypes = require(script.Parent.Parent.util.libtypes)
local logger = require(script.Parent.Parent.util.logger)

local middleware_map: { [number]: { libtypes.Middleware } } = {}

local function middleware(t: libtypes.Intermediate<any, any, any>, mw: libtypes.Middleware)
	local entry = middleware_map[t.id] or {}
	table.insert(entry, mw)
	middleware_map[t.id] = entry
end
local function get(id: number): { libtypes.Middleware }?
	return middleware_map[id]
end

local function run_middleware(id: number, plr: Player)
	local mw = middleware_map[id]
	if mw then
		for _, v in mw do
			-- a middleware that throws refuses
			local ran, allowed = pcall(v, id, plr)
			if not ran then
				logger.orange(`MIDDLEWARE FAILED FOR #{id}: {allowed}`)
				return false
			end
			if not allowed then
				return false
			end
		end
	end
	return true
end

return table.freeze({
	run_middleware = run_middleware,
	middleware = middleware,
	get = get,
})
