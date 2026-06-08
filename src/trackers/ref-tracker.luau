local current: { unknown }

return table.freeze({
	set = function(refs)
		current = refs
	end,
	get = function()
		return current
	end,
})
