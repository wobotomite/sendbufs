local libtypes = require(script.Parent.Parent.util.libtypes)
local logger = require(script.Parent.Parent.util.logger)

local connection_map: { [number]: { libtypes.Connection } } = {}
-- reliable events that arrived before anything connected, handed to the first connection like the engine's own queue
local held: { [number]: { n: number, dropped: boolean, [number]: unknown } } = {}
local MAX_HELD = 256

-- lists are swapped, never edited, so a dispatch that is mid-loop keeps the one it started with
local function add(id: number, cb: libtypes.Connection)
	local entry = table.clone(connection_map[id] or {})
	assert(not table.find(entry, cb), "FUNCTION ALREADY CONNECTED TO THIS EVENT")
	table.insert(entry, cb)
	connection_map[id] = entry

	local connected = true
	local queue = held[id]
	if queue then
		held[id] = nil
		-- deferred so the caller has its disconnect before the first one runs
		for i = 1, queue.n do
			task.defer(function()
				if connected then
					cb(queue[i])
				end
			end)
		end
	end

	local function remove()
		if not connected then
			return
		end
		connected = false
		local index = table.find(connection_map[id], cb)
		if index then
			local copy = table.clone(connection_map[id])
			table.remove(copy, index)
			-- nil, not {}, so the readers see no listeners
			connection_map[id] = if #copy > 0 then copy else nil
		end
	end

	return remove
end

local function get(id: number): { libtypes.Connection }?
	return connection_map[id]
end

local function hold(id: number, value: unknown)
	local queue = held[id]
	if not queue then
		queue = { n = 0, dropped = false }
		held[id] = queue
	end
	if queue.n == MAX_HELD then
		if not queue.dropped then
			queue.dropped = true
			logger.red(
				`EVENT #{id} GOT {MAX_HELD} MESSAGES BEFORE ANYTHING CONNECTED, LATER ONES ARE DROPPED UNTIL ONE DOES`
			)
		end
		return
	end
	queue.n += 1
	queue[queue.n] = value
end

return table.freeze({
	add = add,
	get = get,
	hold = hold,
})
