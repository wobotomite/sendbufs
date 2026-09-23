local current: { unknown }?

return table.freeze({
	set = function(refs: { unknown }?)
		current = refs
	end,
	get = function()
		return current
	end,
})
