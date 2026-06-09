--!native
--!optimize 2
local constants = require(script.Parent.Parent.constants)
local libtypes = require(script.Parent.libtypes)

local current: libtypes.Buffer

local size: number
local cursor: number
local inner: buffer
local references: { [number]: unknown }

local function alloc(bytes: number)
	if not (cursor + bytes >= size) then
		return
	end

	size = math.floor(size * 1.5)

	local newBuffer = buffer.create(size)
	buffer.copy(newBuffer, 0, inner)

	inner = newBuffer
end

local function dyn_alloc(bytes: number)
	while cursor + bytes >= size do
		size = math.floor(size * 1.5)
	end

	local newBuffer = buffer.create(size)
	buffer.copy(newBuffer, 0, inner)

	inner = newBuffer
end

local bufferWriter = {}

bufferWriter.alloc = alloc
bufferWriter.dyn_alloc = dyn_alloc

function bufferWriter.u8(value: number)
	alloc(1)
	buffer.writeu8(inner, cursor, value)
	cursor += 1
end

function bufferWriter.i8(value: number)
	alloc(1)
	buffer.writei8(inner, cursor, value)
	cursor += 1
end

function bufferWriter.reference(value: any)
	if not value then
		value = constants.VOID
	end
	table.insert(references, value)
	local index = #references
	print("added", value, references)
	buffer.writeu8(inner, cursor, index)
	cursor += 1
end

function bufferWriter.u16(value: number)
	alloc(2)
	buffer.writeu16(inner, cursor, value)
	cursor += 2
end

function bufferWriter.i16(value: number)
	alloc(2)
	buffer.writeu16(inner, cursor, value)
	cursor += 2
end

function bufferWriter.u32(value: number)
	alloc(4)
	buffer.writeu32(inner, cursor, value)
	cursor += 4
end

function bufferWriter.writestring(value: string)
	buffer.writestring(inner, cursor, value)
	cursor += string.len(value)
end

function bufferWriter.i32(value: number)
	alloc(4)
	buffer.writei32(inner, cursor, value)
	cursor += 4
end

function bufferWriter.f32NoAlloc(value: number)
	buffer.writef32(inner, cursor, value)
	cursor += 4
end

function bufferWriter.f64NoAlloc(value: number)
	buffer.writef64(inner, cursor, value)
	cursor += 4
end

function bufferWriter.f32(value: number)
	alloc(4)
	buffer.writef32(inner, cursor, value)
	cursor += 4
end

function bufferWriter.f64(value: number)
	alloc(8)
	buffer.writef64(inner, cursor, value)
	cursor += 8
end

function bufferWriter.copy(value)
	buffer.copy(inner, cursor, value)
	cursor += buffer.len(value)
end

function bufferWriter.bool(val: boolean)
	alloc(1)
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
