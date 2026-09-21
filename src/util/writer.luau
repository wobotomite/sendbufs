--!native
--!optimize 2
local constants = require(script.Parent.Parent.constants)
local libtypes = require(script.Parent.libtypes)

local current: libtypes.Buffer

local size: number
local cursor: number
local inner: buffer
local references: { [number]: unknown }

local function grow(bytes: number)
	local needed = cursor + bytes
	repeat
		size *= 2
	until size >= needed

	local newBuffer = buffer.create(size)
	buffer.copy(newBuffer, 0, inner, 0, cursor)

	inner = newBuffer
end

local bufferWriter = {}

function bufferWriter.alloc(bytes: number)
	if cursor + bytes > size then
		grow(bytes)
	end
end

function bufferWriter.u8(value: number)
	if cursor + 1 > size then
		grow(1)
	end
	buffer.writeu8(inner, cursor, value)
	cursor += 1
end

function bufferWriter.i8(value: number)
	if cursor + 1 > size then
		grow(1)
	end
	buffer.writei8(inner, cursor, value)
	cursor += 1
end

function bufferWriter.reference(value: any)
	if cursor + 1 > size then
		grow(1)
	end
	if value == nil then
		value = constants.VOID
	end
	local index = #references + 1
	references[index] = value
	buffer.writeu8(inner, cursor, index)
	cursor += 1
end

function bufferWriter.u16(value: number)
	if cursor + 2 > size then
		grow(2)
	end
	buffer.writeu16(inner, cursor, value)
	cursor += 2
end

function bufferWriter.i16(value: number)
	if cursor + 2 > size then
		grow(2)
	end
	buffer.writei16(inner, cursor, value)
	cursor += 2
end

function bufferWriter.u32(value: number)
	if cursor + 4 > size then
		grow(4)
	end
	buffer.writeu32(inner, cursor, value)
	cursor += 4
end

-- LEB128: 7 bits per byte, so lengths under 128 cost one byte
function bufferWriter.varint(value: number)
	if cursor + 8 > size then
		grow(8)
	end
	while value >= 128 do
		buffer.writeu8(inner, cursor, value % 128 + 128)
		cursor += 1
		value //= 128
	end
	buffer.writeu8(inner, cursor, value)
	cursor += 1
end

function bufferWriter.writestring(value: string)
	local len = #value
	if cursor + len > size then
		grow(len)
	end
	buffer.writestring(inner, cursor, value)
	cursor += len
end

function bufferWriter.i32(value: number)
	if cursor + 4 > size then
		grow(4)
	end
	buffer.writei32(inner, cursor, value)
	cursor += 4
end

function bufferWriter.f32NoAlloc(value: number)
	buffer.writef32(inner, cursor, value)
	cursor += 4
end

function bufferWriter.f64NoAlloc(value: number)
	buffer.writef64(inner, cursor, value)
	cursor += 8
end

function bufferWriter.f32(value: number)
	if cursor + 4 > size then
		grow(4)
	end
	buffer.writef32(inner, cursor, value)
	cursor += 4
end

function bufferWriter.f64(value: number)
	if cursor + 8 > size then
		grow(8)
	end
	buffer.writef64(inner, cursor, value)
	cursor += 8
end

function bufferWriter.copy(value)
	buffer.copy(inner, cursor, value)
	cursor += buffer.len(value)
end

function bufferWriter.bool(val: boolean)
	if cursor + 1 > size then
		grow(1)
	end
	buffer.writeu8(inner, cursor, if val then 1 else 0)
	cursor += 1
end

function bufferWriter.load(channel: libtypes.Buffer)
	current = channel
	size = channel.size
	cursor = channel.cursor
	references = channel.references
	inner = channel.inner
end

function bufferWriter.export()
	current.size = size
	current.cursor = cursor
	current.references = references
	current.inner = inner

	return current
end

return bufferWriter
