local libtypes = require(script.Parent.Parent.util.libtypes)
local logger = require(script.Parent.Parent.util.logger)
local remotes: { [number]: libtypes.Intermediate<any, any, any> } = {}

local function map(key: number, remote: any)
	if remotes[key] then
		logger.orange(`REMOTE #{key} ALREADY EXISTS`)
		return
	end
	remotes[key] = remote
end

local function get()
	return remotes
end

return {
	map = map,
	get = get,
}
