--!native
--!optimize 2
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

-- tables are copied so a ref carries what they held at fire time, not at flush
local function snapshot(value: any, seen: { [any]: any }): any
	if type(value) ~= "table" then
		return value
	end
	local copy = seen[value]
	if copy == nil then
		copy = {}
		seen[value] = copy
		for k, v in pairs(value) do
			copy[k] = snapshot(v, seen)
		end
	end
	return copy
end

local bufferWriter = {}

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
	-- nil is index 0 and takes no slot, refs start at 1
	local index = 0
	if value ~= nil then
		if type(value) == "table" then
			value = snapshot(value, {})
		end
		index = #references + 1
		references[index] = value
	end
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
	-- integers under 2^53 are exact and fit the 8 bytes the reader accepts
	if value < 0 or value >= 2 ^ 53 or value // 1 ~= value then
		error(`VARINT TAKES AN INTEGER FROM 0 TO 2^53 - 1, GOT {value}`)
	end
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

function bufferWriter.bool(val: boolean)
	if cursor + 1 > size then
		grow(1)
	end
	buffer.writeu8(inner, cursor, if val then 1 else 0)
	cursor += 1
end

function bufferWriter.load(channel: libtypes.Buffer)
	current = channel
	cursor = channel.cursor
	references = channel.references
	inner = channel.inner
	size = buffer.len(inner)
end

function bufferWriter.export()
	current.cursor = cursor
	current.inner = inner

	return current
end

-- one message: its remote id, then its payload
function bufferWriter.message(target: libtypes.Buffer, id: number, write: (any) -> (), data: any)
	bufferWriter.load(target)
	bufferWriter.u8(id)
	write(data)
	bufferWriter.export()
end

return bufferWriter
