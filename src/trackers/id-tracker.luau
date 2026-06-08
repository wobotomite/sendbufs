local globalid = 0

function take()
	globalid += 1
	return globalid
end
function get()
	return globalid
end

return table.freeze({
	take = take,
	get = get,
})
