local libtypes = require(script.Parent.Parent.util.libtypes)
local remotes: { [number]: libtypes.Intermediate<any, any, any> } = {}

function map(key: number, remote: any)
	if remote[key] then
		warn(`REMOTE #{key} ALREADY EXISTS`)
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
