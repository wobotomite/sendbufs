return function(b: any, refs: { unknown }?)
	if refs and typeof(refs) ~= "table" then
		return false
	end
	return typeof(b) == "buffer" and buffer.len(b) > 0
end
