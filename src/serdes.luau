--!native
local buffer_writer = require("./buffer-writer")

local alloc = buffer_writer.alloc
local dyn_alloc = buffer_writer.dyn_alloc
local u8 = buffer_writer.u8
local u16 = buffer_writer.u16
local u32 = buffer_writer.u32
local i8 = buffer_writer.i8
local i16 = buffer_writer.i16
local i32 = buffer_writer.i32
local f32 = buffer_writer.f32
local btrue = buffer_writer.btrue
local bfalse = buffer_writer.bfalse
local reference = buffer_writer.reference
local writestring = buffer_writer.writestring;

export type serdes_data<T> = {
	read: (buff: buffer_writer.buffer_writer, cursor: number) -> (T, number),
	write: (buff: buffer_writer.buffer_writer, v: T) -> (),
}
do
	local data: serdes_data<boolean> = {
		read = function(b, o)
			return (buffer.readu8(b.buff, o) == 1), 1
		end,
		write = function(b, v)
			alloc(b, 1)
			if v then
				btrue(b)
			else
				bfalse(b)
			end
		end,
	}
	function S_BOOL()
		return data
	end
end
do
	local data: serdes_data<number> = {
		read = function(b, o)
			return buffer.readu8(b.buff, o), 1
		end,
		write = function(b, v)
			alloc(b, 1)
			u8(b, v)
		end,
	}
	function S_U8()
		return data
	end
end
do
	local data: serdes_data<number> = {
		read = function(b, o)
			return buffer.readi8(b.buff, o), 1
		end,
		write = function(b, v)
			alloc(b, 1)
			i8(b, v)
		end,
	}
	function S_I8()
		return data
	end
end

do
	local data: serdes_data<number> = {
		read = function(b, o)
			return buffer.readu16(b.buff, o), 2
		end,
		write = function(b, v)
			alloc(b, 2)
			u16(b, v)
		end,
	}
	function S_U16()
		return data
	end
end
do
	local data: serdes_data<number> = {
		read = function(b, o)
			return buffer.readi16(b.buff, o), 2
		end,
		write = function(b, v)
			alloc(b, 2)
			i16(b, v)
		end,
	}
	function S_I16()
		return data
	end
end

do
	local data: serdes_data<number> = {
		read = function(b, o)
			return buffer.readu32(b.buff, o), 4
		end,
		write = function(b, v)
			alloc(b, 4)
			u32(b, v)
		end,
	}
	function S_U32()
		return data
	end
end
do
	local data: serdes_data<number> = {
		read = function(b, o)
			return buffer.readi32(b.buff, o), 4
		end,
		write = function(b, v)
			alloc(b, 4)
			i32(b, v)
		end,
	}
	function S_I32()
		return data
	end
end

do
	function S_TUPLE(...: serdes_data<any>)
		local packed = table.pack(...)
		local tuple_len = packed.n
		local data: serdes_data<{ any }> = {
			read = function(b, cursor)
				local len = buffer.readu8(b.buff, cursor)
				local array = {}
				local arr_cursor = cursor + 1
				for i = 1, len do
					local v, len = packed[i].read(b, arr_cursor)
					array[i] = v
					arr_cursor += len
				end
				return array, arr_cursor - cursor
			end,
			write = function(b, v)
				alloc(b, 1)
				u8(b, tuple_len)
				for i = 1, tuple_len do
					packed[i].write(b, v[i])
				end
			end,
		}

		return data
	end
end
do
	function S_ARRAY<T>(t: serdes_data<T>)
		local read, write = t.read, t.write
		local data: serdes_data<{ T }> = {
			read = function(b, cursor)
				local len = buffer.readu16(b.buff, cursor)
				local array = {}
				local arr_cursor = cursor + 2
				for i = 1, len do
					local v, len = read(b, arr_cursor)
					array[i] = v
					arr_cursor += len
				end
				return array, arr_cursor - cursor
			end,
			write = function(b, v)
				local s = #v
				alloc(b, 2)
				u16(b, s)
				for i = 1, s do
					write(b, v[i])
				end
			end,
		}
		return data
	end
end
do
	local map = {}
	function get_struct(template: { [string]: serdes_data<any> })
		if map[template] ~= nil then
			return map[template], #map[template]
		end
		local converted_struct = {}
		for i, v in template do
			converted_struct[#converted_struct + 1] = { index = i, val = v }
		end
		table.sort(converted_struct, function(a0, a1): boolean
			return a0.index > a1.index
		end)
		local len = #converted_struct
		map[template] = converted_struct
		return converted_struct, len
	end

	function S_STRUCT(template: { [string]: serdes_data<any> })
		local ordered, len = get_struct(template)

		print(ordered, len, "STRUCT")
		local data: serdes_data<{ [string]: serdes_data<any> }> = {
			read = function(buff, cursor)
				local length = buffer.readu8(buff.buff, cursor)
				local str_cursor = cursor + 1
				local struct = {}
				for i = 1, length do
					local r = ordered[i]
					local value, offset = r.val.read(buff, str_cursor)
					struct[r.index] = value
					str_cursor += offset
				end
				return struct, str_cursor - cursor
			end,
			write = function(b, v)
				alloc(b, 1)
				u8(b, len)
				for i = 1, len do
					local r = ordered[i]
					r.val.write(b, v[r.index])
				end
			end,
		}
		return data
	end
end

do
	function S_OPTIONAL<T>(v: serdes_data<T>): serdes_data<T?>
		local read, write = v.read, v.write
		return {
			read = function(b, cursor)
				if buffer.readu8(b.buff, cursor) == 0 then
					return nil, 1
				else
					local item, length = read(b, cursor + 1)
					return item, length + 1
				end
			end,
			write = function(b, value)
				local exists = value ~= nil
				alloc(b, 1)
				if exists then
					btrue(b)
				else
					bfalse(b)
				end
				if exists then
					write(b, value :: T)
				end
			end,
		}
	end
end

do
	local data: serdes_data<any> = {
		read = function(b, cursor)
			local v = buffer.readu8(b.buff, cursor)
			return b.references[v], 1
		end,
		write = function(b, v)
			alloc(b, 1)
			reference(b, v)
		end,
	}
	function S_REF()
		return data
	end
end

do
	local data: serdes_data<nil> = {
		read = function()
			return nil,0
		end,
		write = function()
		end,
	}
	function S_NONE()
		return data
	end
end

do 
	local bor = bit32.bor;
	local data: serdes_data<vector> = {
		read = function(b, cursor)
			local c = cursor;
			local x = buffer.readi16(b.buff, c);c+=2;
			local y = buffer.readi16(b.buff, c);c+=2;
			local z = buffer.readi16(b.buff, c);c+=2;
			return vector.create(x, y, z), c-cursor
		end,
		write = function(b, v)
			alloc(b, 2*3)
			i16(b, bor(v.x,0))
			i16(b, bor(v.y,0))
			i16(b, bor(v.z or 0,0))
		end,
	}

	function VECI16()
		return data;
	end
end

do 
	local bor = bit32.bor;
	local data: serdes_data<vector> = {
		read = function(b, cursor)
			local c = cursor;
			local x = buffer.readi32(b.buff, c);c+=4;
			local y = buffer.readi32(b.buff, c);c+=4;
			local z = buffer.readi32(b.buff, c);c+=4;
			return vector.create(x, y, z), c-cursor
		end,
		write = function(b, v)
			alloc(b, 4*3)
			i32(b, bor(v.x,0))
			i32(b, bor(v.y,0))
			i32(b, bor(v.z or 0,0))
		end,
	}

	function VECI32()
		return data;
	end
end

do 
	local data: serdes_data<vector> = {
		read = function(b, cursor)
			local c = cursor;
			local x = buffer.readf32(b.buff, c);c+=4;
			local y = buffer.readf32(b.buff, c);c+=4;
			local z = buffer.readf32(b.buff, c);c+=4;
			return vector.create(x, y, z), c-cursor
		end,
		write = function(b, v)
			alloc(b, 4*3)
			f32(b, v.x)
			f32(b, v.y)
			f32(b, v.z or 0)
		end,
	}

	function VECF32()
		return data;
	end
end

do 
	local data: serdes_data<CFrame> = {
		read = function(b, cursor)
			local c = cursor;
			local x = buffer.readf32(b.buff, c);c+=4;
			local y = buffer.readf32(b.buff, c);c+=4;
			local z = buffer.readf32(b.buff, c);c+=4;
			local rx = buffer.readf32(b.buff, c);c+=4;
			local ry = buffer.readf32(b.buff, c);c+=4;
			local rz = buffer.readf32(b.buff, c);c+=4;
			return CFrame.Angles(rx, ry, rz)+Vector3.new(x, y, z), c-cursor
		end,
		write = function(b, v)
			
			local unit,rot = v:ToAxisAngle();
			unit*=rot;

			alloc(b, 4*6)
			f32(b, v.x)
			f32(b, v.y)
			f32(b, v.z)
			f32(b, unit.x)
			f32(b, unit.y)
			f32(b, unit.z)
			
		end,
	}

	function CFRAME()
		return data;
	end
end



do
	local data: serdes_data<string> = {
		read = function(b, cursor)
			local c = cursor;
			local len = buffer.readu16(b.buff, c);c+=2;
			local str= buffer.readstring(b.buff, c, len);
			c+=len;
			return str, c-cursor
		end,
		write = function(b, v)
			local len = #v;
			alloc(b, 2)
			u16(b, len);
			dyn_alloc(b, len);
			writestring(b, v)
		end,
	}

	function STRING()
		return data;
	end
end



return table.freeze({
	NONE = (S_NONE()::never)::nil,
	REF = (S_REF() :: never) :: any,
	BOOL = (S_BOOL() :: never) :: boolean,
	U8 = (S_U8() :: never) :: number,
	I8 = (S_I8() :: never) :: number,
	U16 = (S_U16() :: never) :: number,
	I16 = (S_I16() :: never) :: number,
	U32 = (S_U32() :: never) :: number,
	I32 = (S_I32() :: never) :: number,
	VECI16 = (VECI16()::never)::vector,
	VECI32 = (VECI32()::never)::vector,
	VECF32 = (VECF32()::never)::vector,
	STRING = (STRING()::never)::string,
	CFRAME = (CFRAME()::never)::CFrame,
	ARRAY = (S_ARRAY :: never) :: <T>(T) -> { T },
	STRUCT = (S_STRUCT :: never) :: <T>(T) -> T,
	OPTIONAL = (S_OPTIONAL :: never) :: <T>(T) -> T?,
})
