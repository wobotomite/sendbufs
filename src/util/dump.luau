local libtypes = require(script.Parent.libtypes)
return @native function(b: libtypes.Buffer): (buffer, { unknown }?)
	local cursor = b.cursor
	local dumpBuffer = buffer.create(cursor)
	buffer.copy(dumpBuffer, 0, b.inner, 0, cursor)
	return dumpBuffer, if #b.references > 0 then b.references else nil
end
