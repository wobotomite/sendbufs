local libtypes = require(script.Parent.Parent.util.libtypes)

local connection_map: { [number]: { libtypes.Connection } } = {}

function add(id: number, cb: libtypes.Connection)
	local entry = connection_map[id] or {}
	table.insert(entry, cb)
	local function remove()
		local arr = connection_map[id]
		local index = table.find(arr, cb)
		if index then
			table.remove(connection_map[id], index)
		end
	end

	connection_map[id] = entry

	return remove
end

function get(id: number): { libtypes.Connection }?
	return connection_map[id]
end

return table.freeze({
	add = add,
	get = get,
})
