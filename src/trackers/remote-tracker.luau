local libtypes = require(script.Parent.Parent.util.libtypes)
local logger = require(script.Parent.Parent.util.logger)
local remotes: { [number]: libtypes.Intermediate<any, any, any> } = {}

function map(key: number, remote: any)
	if remote[key] then
		logger.orange(`REMOTE #{key} ALREADY EXISTS`)
		return
	end
	remotes[key] = remote
end

function get()
	return remotes
end

return {
	map = map,
	get = get,
}
