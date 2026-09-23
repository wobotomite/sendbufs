local libtypes = require(script.Parent.libtypes)
local logger = require(script.Parent.logger)
local callbacks: { [number]: libtypes.Callback } = {}

local function set(id: number, cb: libtypes.Callback)
	if callbacks[id] then
		logger.red(`CALLBACKS CAN ONLY BE SET ONCE! ID #{id}, THE FIRST ONE IS KEPT`)
		return
	end
	callbacks[id] = cb
end

local function get(id: number): libtypes.Callback?
	return callbacks[id]
end

return table.freeze({
	set = set,
	get = get,
})
