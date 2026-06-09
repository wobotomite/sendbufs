local libtypes = require(script.Parent.libtypes)
local logger = require(script.Parent.logger)
local callbacks: { [number]: libtypes.Callback } = {}

function set(id: number, cb: libtypes.Callback)
	if callbacks[id] then
		logger.orange(`CALLBACKS CAN ONLY BE SET ONCE! ID #{id}`)
		return
	end
	callbacks[id] = cb
end

function get(id: number): libtypes.Callback?
	return callbacks[id]
end

return table.freeze({
	set = set,
	get = get,
})
