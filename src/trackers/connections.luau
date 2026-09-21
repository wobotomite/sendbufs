local libtypes = require(script.Parent.Parent.util.libtypes)

local connection_map: { [number]: { libtypes.Connection } } = {}

-- lists are swapped, never edited, so a dispatch that is mid-loop keeps the one it started with
local function add(id: number, cb: libtypes.Connection)
	local entry = table.clone(connection_map[id] or {})
	assert(not table.find(entry, cb), "FUNCTION ALREADY CONNECTED TO THIS EVENT")
	table.insert(entry, cb)
	connection_map[id] = entry

	local connected = true
	local function remove()
		if not connected then
			return
		end
		connected = false
		local index = table.find(connection_map[id], cb)
		if index then
			local copy = table.clone(connection_map[id])
			table.remove(copy, index)
			connection_map[id] = copy
		end
	end

	return remove
end

local function get(id: number): { libtypes.Connection }?
	return connection_map[id]
end

return table.freeze({
	add = add,
	get = get,
})
