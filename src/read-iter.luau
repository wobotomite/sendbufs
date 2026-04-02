local buffer_writer = require("./buffer-writer")

local remotes = require("./remotes")

local from = buffer_writer.from

@native
function read_iter(reader_prop: "schema" | "schema_out", b: buffer, refs: { unknown }?)
	local cursor = 0
	local totalLen = buffer.len(b)
	local sb = from(b)
	sb.references = refs or {}
	return function()
		if cursor >= totalLen then
			return
		end
		local rid = buffer.readu8(b, cursor)
		local remo = remotes[rid]
		cursor += 1
		local value, nc = remo[reader_prop].read(sb, cursor)
		cursor += nc
		return rid, value
	end
end

return (
	read_iter :: never
) :: <T...>(reader_prop: "schema" | "schema_out", b: buffer, refs: { unknown }?) -> () -> (number, any)
