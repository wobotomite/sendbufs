local types = require("./types")
type buffer_writer = types.buffer_writer

function create(): buffer_writer
	return {
		size = 12,
		references = {},
		buff = buffer.create(12),
		cursor = 0,
	}
end

function from(b: buffer)
	local len = buffer.len(b)
	local nb: buffer_writer = {
		buff = buffer.create(len),
		size = len,
		cursor = 0,
		references = {},
	}
	buffer.copy(nb.buff, 0, b)
	return nb
end

function alloc(buf: buffer_writer, bytes: number)
	if not (buf.cursor + bytes >= buf.size) then
		return
	end
	buf.size = math.floor(buf.size * 1.5)
	local newBuffer = buffer.create(buf.size)
	buffer.copy(newBuffer, 0, buf.buff)
	buf.buff = newBuffer
end
function dyn_alloc(buf: buffer_writer, bytes: number)
	while buf.cursor + bytes > buf.size do
		buf.size = math.floor(buf.size * 1.5)
	end
	local newBuffer = buffer.create(buf.size)
	buffer.copy(newBuffer, 0, buf.buff)
	buf.buff = newBuffer
end

function u8(buf: buffer_writer, value: number)
	buffer.writeu8(buf.buff, buf.cursor, value)
	buf.cursor += 1
end

function i8(buf: buffer_writer, value: number)
	buffer.writei8(buf.buff, buf.cursor, value)
	buf.cursor += 1
end

function reference(buf: buffer_writer, value: any)
	table.insert(buf.references, value)
	local index = #buf.references
	buffer.writeu8(buf.buff, buf.cursor, index)
	buf.cursor += 1
end

function u16(buf: buffer_writer, value: number)
	buffer.writeu16(buf.buff, buf.cursor, value)
	buf.cursor += 2
end

function i16(buf: buffer_writer, value: number)
	buffer.writeu16(buf.buff, buf.cursor, value)
	buf.cursor += 2
end

function u32(buf: buffer_writer, value: number)
	buffer.writeu32(buf.buff, buf.cursor, value)
	buf.cursor += 4
end

function writestring(buf: buffer_writer, value: string)
	buffer.writestring(buf.buff, buf.cursor, value)
	buf.cursor += string.len(value)
end

function i32(buf: buffer_writer, value: number)
	buffer.writei32(buf.buff, buf.cursor, value)
	buf.cursor += 4
end

function f32(buf: buffer_writer, value: number)
	buffer.writef32(buf.buff, buf.cursor, value)
	buf.cursor += 4
end

function f64(buf: buffer_writer, value: number)
	buffer.writef64(buf.buff, buf.cursor, value)
	buf.cursor += 8
end

function copy(buf: buffer_writer, value)
	buffer.copy(buf.buff, buf.cursor, value)
	buf.cursor += buffer.len(value)
end

function btrue(buf: buffer_writer)
	buffer.writeu8(buf.buff, buf.cursor, 1)
	buf.cursor += 1
end

function bfalse(buf: buffer_writer)
	buffer.writeu8(buf.buff, buf.cursor, 0)
	buf.cursor += 1
end

return table.freeze({
	create = create,
	alloc = alloc,
	u8 = u8,
	i8 = i8,
	u16 = u16,
	i16 = i16,
	u32 = u32,
	i32 = i32,
	f32 = f32,
	f64 = f64,
	copy = copy,
	btrue = btrue,
	bfalse = bfalse,
	reference = reference,
	writestring = writestring,
	dyn_alloc = dyn_alloc,
	from = from,
})
