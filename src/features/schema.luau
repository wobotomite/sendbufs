--!native
--!optimize 2
local constants = require(script.Parent.Parent.constants)
local ref_tracker = require(script.Parent.Parent.trackers["ref-tracker"])
local libtypes = require(script.Parent.Parent.util.libtypes)
local writer = require(script.Parent.Parent.util.writer)

local b_u8 = writer.u8
local b_varint = writer.varint
local writestring = writer.writestring

local VOID = constants.VOID

local freeze = table.freeze :: <T>(T) -> T

-- inner schema of every maybe(), so struct can fold the presence byte into its flag bits
local maybe_inner: { [any]: libtypes.Schema<any> } = setmetatable({}, { __mode = "k" }) :: any

local function read_varint(b: buffer, o: number): (number, number)
	local byte = buffer.readu8(b, o)
	if byte < 128 then
		return byte, 1
	end
	local value, scale, n = byte - 128, 128, 1
	repeat
		-- the writer never emits more than 8 bytes; past that the value runs to inf and NaN
		if n == 8 then
			error("VARINT TOO LONG")
		end
		byte = buffer.readu8(b, o + n)
		value += byte % 128 * scale
		scale *= 128
		n += 1
	until byte < 128
	return value, n
end

local function read_len(b: buffer, o: number): (number, number)
	local len, n = buffer.readu8(b, o), 1
	if len >= 128 then
		len, n = read_varint(b, o)
		-- an element costs at least a bit, so a count past that is forged
		if len > buffer.len(b) * 8 then
			error("LENGTH EXCEEDS THE PACKET")
		end
	end
	return len, n
end

local bool: libtypes.Schema<boolean> = {
	read = function(buf, o)
		return (buffer.readu8(buf, o) == 1), 1
	end,
	write = writer.bool,
	__T = nil :: never,
}

local u8: libtypes.Schema<number> = {
	read = function(buf, o)
		return buffer.readu8(buf, o), 1
	end,
	write = b_u8,
	__T = nil :: never,
}
local u16: libtypes.Schema<number> = {
	read = function(buf, o)
		return buffer.readu16(buf, o), 2
	end,
	write = writer.u16,
	__T = nil :: never,
}
local u32: libtypes.Schema<number> = {
	read = function(buf, o)
		return buffer.readu32(buf, o), 4
	end,
	write = writer.u32,
	__T = nil :: never,
}

local i8: libtypes.Schema<number> = {
	read = function(buf, o)
		return buffer.readi8(buf, o), 1
	end,
	write = writer.i8,
	__T = nil :: never,
}
local i16: libtypes.Schema<number> = {
	read = function(buf, o)
		return buffer.readi16(buf, o), 2
	end,
	write = writer.i16,
	__T = nil :: never,
}
local i32: libtypes.Schema<number> = {
	read = function(buf, o)
		return buffer.readi32(buf, o), 4
	end,
	write = writer.i32,
	__T = nil :: never,
}

-- whole numbers up to 2^53, a byte per 7 bits
local uvar: libtypes.Schema<number> = {
	read = read_varint,
	write = b_varint,
	__T = nil :: never,
}
local ivar: libtypes.Schema<number> = {
	read = function(buf, o)
		local z, n = read_varint(buf, o)
		if z % 2 == 0 then
			return z / 2, n
		end
		return -(z + 1) / 2, n
	end,
	write = function(v)
		-- zigzag, so a small negative is as short as a small positive
		b_varint(if v < 0 then -2 * v - 1 else 2 * v)
	end,
	__T = nil :: never,
}

local f32: libtypes.Schema<number> = {
	read = function(buf, o)
		return buffer.readf32(buf, o), 4
	end,
	write = writer.f32,
	__T = nil :: never,
}

local f64: libtypes.Schema<number> = {
	read = function(buf, o)
		return buffer.readf64(buf, o), 8
	end,
	write = writer.f64,
	__T = nil :: never,
}

local function maybe<T>(input: libtypes.Schema<T>): libtypes.Schema<T?>
	local read, write = input.read, input.write
	local schema: libtypes.Schema<T?> = {
		read = function(buf, offset)
			if buffer.readu8(buf, offset) == 0 then
				return nil, 1
			else
				local item, length = read(buf, offset + 1)
				return item, length + 1
			end
		end,
		write = function(v)
			if v == nil then
				b_u8(0)
			else
				b_u8(1)
				write(v)
			end
		end,
		__T = nil :: never,
	}
	maybe_inner[schema] = input
	return schema
end

local bool_array: libtypes.Schema<{ boolean }> = {
	read = function(b, cursor)
		local len, n = read_len(b, cursor)
		local out = table.create(len) :: { boolean }
		local c = cursor + n
		local byte = 0
		for i = 1, len do
			if i % 8 == 1 then
				byte = buffer.readu8(b, c)
				c += 1
			end
			out[i] = byte % 2 == 1
			byte //= 2
		end
		return out, c - cursor
	end,
	write = function(v)
		local len = #v
		b_varint(len)
		local byte, weight = 0, 1
		for i = 1, len do
			if v[i] then
				byte += weight
			end
			if weight == 128 then
				b_u8(byte)
				byte, weight = 0, 1
			else
				weight *= 2
			end
		end
		if weight ~= 1 then
			b_u8(byte)
		end
	end,
	__T = nil :: never,
}

local function array<T>(input: libtypes.Schema<T>): libtypes.Schema<{ T }>
	if input == bool :: any then
		return bool_array :: any
	end
	local read, write = input.read, input.write
	return {
		read = function(b, cursor)
			local len, n = read_len(b, cursor)
			local arr_cursor = cursor + n
			local out: { T } = table.create(math.min(len, buffer.len(b) - arr_cursor))
			for i = 1, len do
				local v, size = read(b, arr_cursor)
				out[i] = v
				arr_cursor += size
			end
			return out, arr_cursor - cursor
		end,
		write = function(v)
			local s = #v
			b_varint(s)
			for i = 1, s do
				write(v[i])
			end
		end,
		__T = nil :: never,
	}
end

local function map<K, V>(k: libtypes.Schema<K>, v: libtypes.Schema<V>): libtypes.Schema<{ [K]: V }>
	local kread, kwrite = k.read, k.write
	local vread, vwrite = v.read, v.write

	return {
		read = function(b, cursor)
			local len, n = read_len(b, cursor)
			local out = {}
			local map_cursor = cursor + n
			for i = 1, len do
				local key, klen = kread(b, map_cursor)
				map_cursor += klen
				local value, vlen = vread(b, map_cursor)
				map_cursor += vlen
				out[key] = value
			end
			return out, map_cursor - cursor
		end,
		write = function(input)
			local count = 0
			for _ in input do
				count += 1
			end
			b_varint(count)
			for key, value in input do
				kwrite(key)
				vwrite(value)
			end
		end,
		__T = nil :: never,
	}
end

local function set<K>(k: libtypes.Schema<K>): libtypes.Schema<{ [K]: boolean }>
	local kread, kwrite = k.read, k.write

	return {
		read = function(b, cursor)
			local len, n = read_len(b, cursor)
			local out = {}
			local set_cursor = cursor + n
			for i = 1, len do
				local key, klen = kread(b, set_cursor)
				set_cursor += klen
				out[key] = true
			end
			return out, set_cursor - cursor
		end,
		write = function(input)
			local count = 0
			for _, v in input do
				if v then
					count += 1
				end
			end
			b_varint(count)
			for key, v in input do
				if v then
					kwrite(key)
				end
			end
		end,
		__T = nil :: never,
	}
end

local function struct<T>(input: T & {}): libtypes.Schema<libtypes.GetNestedSchema<T> & {}>
	local names: { string } = {}
	for name in input :: { [string]: any } do
		names[#names + 1] = name
	end
	table.sort(names, function(a0: string, a1: string): boolean
		return a0 > a1
	end)

	-- every bool field and every maybe's presence is one bit in the leading flag bytes
	local flag_names: { string }, flag_maybe: { boolean } = {}, {}
	local bool_names: { string }, bool_offset: { number }, bool_mask: { number } = {}, {}, {}
	local field_names: { string }, field_offset: { number }, field_mask: { number } = {}, {}, {}
	local field_read: { (buffer, number) -> (any, number) }, field_write: { (any) -> () } = {}, {}
	local template: { [string]: any } = {}

	for _, name in names do
		local field: libtypes.Schema<any> = (input :: any)[name]
		local inner = maybe_inner[field]
		local flagged = inner ~= nil or field == bool :: any
		local bit = #flag_names
		template[name] = false

		if flagged then
			flag_names[bit + 1] = name
			flag_maybe[bit + 1] = inner ~= nil
		end
		if flagged and not inner then
			local i = #bool_names + 1
			bool_names[i], bool_offset[i], bool_mask[i] = name, bit // 8, 2 ^ (bit % 8)
		else
			local i = #field_names + 1
			field_names[i] = name
			field_offset[i] = if inner then bit // 8 else 0
			field_mask[i] = if inner then 2 ^ (bit % 8) else 0
			field_read[i] = if inner then inner.read else field.read
			field_write[i] = if inner then inner.write else field.write
		end
	end

	local flag_count, bool_count, field_count = #flag_names, #bool_names, #field_names
	local flag_bytes = (flag_count + 7) // 8

	return {
		read = function(buff, cursor)
			local out = table.clone(template)
			for i = 1, bool_count do
				out[bool_names[i]] = bit32.btest(buffer.readu8(buff, cursor + bool_offset[i]), bool_mask[i])
			end
			local str_cursor = cursor + flag_bytes
			for i = 1, field_count do
				local mask = field_mask[i]
				if mask == 0 or bit32.btest(buffer.readu8(buff, cursor + field_offset[i]), mask) then
					local value, offset = field_read[i](buff, str_cursor)
					out[field_names[i]] = value
					str_cursor += offset
				else
					out[field_names[i]] = nil
				end
			end
			return out :: any, str_cursor - cursor
		end,
		write = function(v)
			local byte, weight = 0, 1
			for i = 1, flag_count do
				local value = (v :: any)[flag_names[i]]
				if value or (value ~= nil and flag_maybe[i]) then
					byte += weight
				end
				if weight == 128 then
					b_u8(byte)
					byte, weight = 0, 1
				else
					weight *= 2
				end
			end
			if weight ~= 1 then
				b_u8(byte)
			end
			for i = 1, field_count do
				local value = (v :: any)[field_names[i]]
				if value ~= nil or field_mask[i] == 0 then
					field_write[i](value)
				end
			end
		end,
		__T = nil :: never,
	}
end

local function vector3<T>(input: libtypes.Schema<T & number>): libtypes.Schema<Vector3>
	local read, write = input.read, input.write
	return {
		read = function(b, o)
			local c = o
			local x, y, z, n
			x, n = read(b, c)
			c += n
			y, n = read(b, c)
			c += n
			z, n = read(b, c)
			c += n
			return Vector3.new(x, y, z), c - o
		end,
		write = function(v: Vector3)
			write(v.X)
			write(v.Y)
			write(v.Z)
		end,
		__T = nil :: never,
	}
end
local function cframe<T>(input: libtypes.Schema<T & number>): libtypes.Schema<CFrame>
	local read, write = input.read, input.write

	return {
		read = function(buff, init)
			local c = init
			local x, y, z, rx, ry, rz, n
			x, n = read(buff, c)
			c += n
			y, n = read(buff, c)
			c += n
			z, n = read(buff, c)
			c += n
			rx, n = read(buff, c)
			c += n
			ry, n = read(buff, c)
			c += n
			rz, n = read(buff, c)
			c += n
			return CFrame.Angles(rx, ry, rz) + Vector3.new(x, y, z), c - init
		end,
		write = function(v: CFrame)
			local rx, ry, rz = v:ToEulerAnglesXYZ()
			write(v.X)
			write(v.Y)
			write(v.Z)
			write(rx)
			write(ry)
			write(rz)
		end,
		__T = nil :: never,
	}
end

local null: libtypes.Schema<nil> = {
	write = function() end,
	read = function()
		return nil, 0
	end,
	__T = nil,
}

local str: libtypes.Schema<string> = {
	read = function(b, cursor)
		local len, n = buffer.readu8(b, cursor), 1
		if len >= 128 then
			len, n = read_len(b, cursor)
		end
		return buffer.readstring(b, cursor + n, len), n + len
	end,
	write = function(v)
		b_varint(#v)
		writestring(v)
	end,
	__T = nil :: never,
}

local ref: libtypes.Schema<any?> = {
	read = function(b, cursor)
		local ref_list = ref_tracker.get()
		if not ref_list then
			return nil, 1
		end
		local obtained_ref = ref_list[buffer.readu8(b, cursor)]
		if obtained_ref == VOID then
			obtained_ref = nil
		end
		return obtained_ref, 1
	end,
	write = writer.reference,
	__T = nil :: never,
}

return freeze({
	maybe = maybe,
	array = array,
	struct = struct,
	map = map,
	set = set,
	vector = vector3,
	cframe = cframe,

	-- primitive:
	ref = ref,
	str = str,
	bool = bool,
	null = null,
	u8 = u8,
	u16 = u16,
	u32 = u32,
	i8 = i8,
	i16 = i16,
	i32 = i32,
	uvar = uvar,
	ivar = ivar,
	f32 = f32,
	f64 = f64,
})
