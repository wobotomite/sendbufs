local ref_tracker = require(script.Parent.Parent.trackers["ref-tracker"])
local libtypes = require(script.Parent.Parent.util.libtypes)
local writer = require(script.Parent.Parent.util.writer)

local alloc = writer.alloc
local dyn_alloc = writer.dyn_alloc
local b_u8 = writer.u8
local b_u16 = writer.u16
local b_u32 = writer.u32
local b_i8 = writer.i8
local b_i16 = writer.i16
local b_i32 = writer.i32
local b_f32 = writer.f32
local b_f64 = writer.f64
local b_bool = writer.bool
local reference = writer.reference
local writestring = writer.writestring

local freeze = table.freeze :: <T>(T) -> T

function bool(): libtypes.Schema<boolean>
	return {
		read = function(buf, o)
			return (buffer.readu8(buf, o) == 1), 1
		end,
		write = function(n)
			alloc(1)
			b_bool(n)
		end,
		__T = nil :: never,
	}
end

function u8(): libtypes.Schema<number>
	return {
		read = function(buf, o)
			return buffer.readu8(buf, o), 1
		end,
		write = function(n)
			alloc(1)
			b_u8(n)
		end,
		__T = nil :: never,
	}
end
function u16(): libtypes.Schema<number>
	return {
		read = function(buf, o)
			return buffer.readu16(buf, o), 2
		end,
		write = function(n)
			alloc(2)
			b_u16(n)
		end,
		__T = nil :: never,
	}
end
function u32(): libtypes.Schema<number>
	return {
		read = function(buf, o)
			return buffer.readu32(buf, o), 4
		end,
		write = function(n)
			alloc(4)
			b_u32(n)
		end,
		__T = nil :: never,
	}
end

function i8(): libtypes.Schema<number>
	return {
		read = function(buf, o)
			return buffer.readi8(buf, o), 1
		end,
		write = function(n)
			alloc(1)
			b_i8(n)
		end,
		__T = nil :: never,
	}
end
function i16(): libtypes.Schema<number>
	return {
		read = function(buf, o)
			return buffer.readi16(buf, o), 2
		end,
		write = function(n)
			alloc(2)
			b_i16(n)
		end,
		__T = nil :: never,
	}
end
function i32(): libtypes.Schema<number>
	return {
		read = function(buf, o)
			return buffer.readi32(buf, o), 4
		end,
		write = function(n)
			alloc(4)
			b_i32(n)
		end,
		__T = nil :: never,
	}
end

function f32(): libtypes.Schema<number>
	return {
		read = function(buf, o)
			return buffer.readf32(buf, o), 4
		end,
		write = function(n)
			alloc(4)
			b_f32(n)
		end,
		__T = nil :: never,
	}
end

function f64(): libtypes.Schema<number>
	return {
		read = function(buf, o)
			return buffer.readf64(buf, o), 8
		end,
		write = function(n)
			alloc(4)
			b_f64(n)
		end,
		__T = nil :: never,
	}
end

function maybe<T>(input: libtypes.Schema<T>): libtypes.Schema<T?>
	local read, write = input.read, input.write
	return {
		read = function(buf, offset)
			if buffer.readu8(buf, offset) == 0 then
				return nil, 1
			else
				local item, length = read(buf, offset + 1)
				return item, length + 1
			end
		end,
		write = function(v)
			local exists = v ~= nil
			alloc(1)
			b_bool(exists)
			if exists then
				write(v)
			end
		end,
		__T = nil :: never,
	}
end

function array<T>(input: libtypes.Schema<T>): libtypes.Schema<{ T }>
	local read, write = input.read, input.write
	return {
		read = function(b, cursor)
			local len = buffer.readu16(b, cursor)
			local array: { T } = {}
			local arr_cursor = cursor + 2
			for i = 1, len do
				local v, len = read(b, arr_cursor)
				array[i] = v
				arr_cursor += len
			end
			return array, arr_cursor - cursor
		end,
		write = function(v)
			local s = #v
			alloc(2)
			b_u16(s)
			for i = 1, s do
				write(v[i])
			end
		end,
		__T = nil :: never,
	}
end
do
	function get_set_key_count<K>(set: { [K]: boolean })
		local count = 0
		for i, v in set do
			if v then
				count += 1
			end
		end
		return count
	end
	function get_map_key_count<K, V>(v: { [K]: V })
		local count = 0
		for i in v do
			count += 1
		end
		return count
	end
end
function map<K, V>(k: libtypes.Schema<K>, v: libtypes.Schema<V>): libtypes.Schema<{ [K]: V }>
	local kread, kwrite = k.read, k.write
	local vread, vwrite = v.read, v.write

	return {
		read = function(b, cursor)
			local len = buffer.readu16(b, cursor)
			local map = {}
			local map_cursor = cursor + 2
			for i = 1, len do
				local k, klen = kread(b, map_cursor)
				map_cursor += klen
				local v, vlen = vread(b, map_cursor)
				map_cursor += vlen
				map[k] = v
			end
			return map, map_cursor - cursor
		end,
		write = function(map)
			b_u16(get_map_key_count(map))
			for i, v in map do
				kwrite(i)
				vwrite(v)
			end
		end,
		__T = nil :: never,
	}
end
function set<K>(k: libtypes.Schema<K>): libtypes.Schema<{ [K]: boolean }>
	local kread, kwrite = k.read, k.write

	return {
		read = function(b, cursor)
			local len = buffer.readu16(b, cursor)
			local map = {}
			local map_cursor = cursor + 2
			for i = 1, len do
				local k, klen = kread(b, map_cursor)
				map_cursor += klen
				map[k] = true
			end
			return map, map_cursor - cursor
		end,
		write = function(set)
			b_u16(get_set_key_count(set))
			for i, v in set do
				if v then
					kwrite(i)
				end
			end
		end,
		__T = nil :: never,
	}
end

type SchemaStruct = {}
do
	local map: { [{}]: { { index: string, val: libtypes.Schema<any> } } } = {}
	function get_struct(template: SchemaStruct)
		if map[template] ~= nil then
			return map[template], #map[template]
		end
		local converted_struct: { { index: string, val: libtypes.Schema<any> } } = {}
		for i, v in template :: { [string]: any } do
			converted_struct[#converted_struct + 1] = { index = i, val = v }
		end
		table.sort(converted_struct, function(a0: { index: string }, a1: { index: string }): boolean
			return a0.index > a1.index
		end)
		local len = #converted_struct
		map[template] = converted_struct
		return converted_struct, len
	end
end

function struct<T>(input: T & {}): libtypes.Schema<libtypes.GetNestedSchema<T> & {}>
	local ordered, len = get_struct(input)
	return {
		read = function(buff, cursor)
			local length = buffer.readu8(buff, cursor)
			local str_cursor = cursor + 1
			local struct = {}
			for i = 1, length do
				local r = ordered[i]
				local value, offset = r.val.read(buff, str_cursor)
				struct[r.index] = value
				str_cursor += offset
			end
			return struct :: any, str_cursor - cursor
		end,
		write = function(v)
			alloc(1)
			b_u8(len)
			for i = 1, len do
				local r = ordered[i]
				r.val.write((v :: any)[r.index])
			end
		end,
		__T = nil :: never,
	}
end

function vector<T>(input: libtypes.Schema<T & number>): libtypes.Schema<Vector3>
	local read, write = input.read, input.write
	return {
		read = function(b, o)
			local c = o
			local x, add = read(b, c)
			c += add
			local y, add = read(b, c)
			c += add
			local z, add = read(b, c)
			c += add
			return Vector3.new(x, y, z), c - o
		end,
		write = function(vector: Vector3)
			write(vector.X)
			write(vector.Y)
			write(vector.Z)
		end,
		__T = nil :: never,
	}
end
function cframe<T>(input: libtypes.Schema<T & number>): libtypes.Schema<CFrame>
	local read, write = input.read, input.write

	return {
		read = function(buff, init)
			local c = init
			local x, o = read(buff, c)
			c += o
			local y, o = read(buff, c)
			c += o
			local z, o = read(buff, c)
			c += o
			local rx, o = read(buff, c)
			c += o
			local ry, o = read(buff, c)
			c += o
			local rz, o = read(buff, c)
			c += o
			return CFrame.Angles(rx, ry, rz) + Vector3.new(x, y, z), c - init
		end,
		write = function(v: CFrame)
			local unit, rot = v:ToAxisAngle()
			unit *= rot
			write(v.X)
			write(v.Y)
			write(v.Z)
			write(unit.X)
			write(unit.Y)
			write(unit.Z)
		end,
		__T = nil :: never,
	}
end

function null(): libtypes.Schema<nil>
	return {
		write = function() end,
		read = function()
			return nil, 0
		end,
		__T = nil,
	}
end

function str(): libtypes.Schema<string>
	return {
		read = function(b, cursor)
			local c = cursor
			local len = buffer.readu16(b, c)
			c += 2
			local str = buffer.readstring(b, c, len)
			c += len
			return str, c - cursor
		end,
		write = function(v)
			local len = #v
			alloc(2)
			b_u16(len)
			dyn_alloc(len)
			writestring(v:sub(1, 65535))
		end,
		__T = nil :: never,
	}
end

function ref(): libtypes.Schema<any?>
	return {
		read = function(b, cursor)
			local ref_list = ref_tracker.get()
			if not ref_list then
				return nil, 1
			end
			return ref_list[buffer.readu8(b, cursor)], 1
		end,
		write = function(v)
			alloc(1)
			reference(v)
		end,
		__T = nil :: never,
	}
end

return freeze({
	maybe = maybe,
	array = array,
	struct = struct,
	map = map,
	set = set,
	vector = vector,
	cframe = cframe,

	-- primitive:
	ref = ref(),
	str = str(),
	bool = bool(),
	null = null(),
	u8 = u8(),
	u16 = u16(),
	u32 = u32(),
	i8 = i8(),
	i16 = i16(),
	i32 = i32(),
	f32 = f32(),
	f64 = f64(),
})
