local libtypes = require(script.Parent.Parent.util.libtypes)
local remotes: { [number]: libtypes.Intermediate<any, any, any> } = {}

-- ids are handed out in order from 1, so the next one is always #remotes + 1
local function take(): number
	local id = #remotes + 1
	-- ids travel as a u8
	assert(id <= 255, "REMOTE LIMIT OF 255 REACHED")
	return id
end

local function map(key: number, remote: any)
	remotes[key] = remote
end

local function get()
	return remotes
end

return table.freeze({
	take = take,
	map = map,
	get = get,
})
