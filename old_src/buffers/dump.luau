local types = require("./types")
return @native function(b: types.buffer_writer): (buffer, { unknown }?)
	local cursor = b.cursor
	local dumpBuffer = buffer.create(cursor)
	buffer.copy(dumpBuffer, 0, b.buff, 0, cursor)
	return dumpBuffer, if #b.references > 0 then b.references else nil
end
