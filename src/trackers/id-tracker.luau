local globalid = 0

local function take()
	globalid += 1
	-- ids travel as a u8
	assert(globalid <= 255, "REMOTE LIMIT OF 255 REACHED")
	return globalid
end
local function get()
	return globalid
end

return table.freeze({
	take = take,
	get = get,
})
