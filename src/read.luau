local buffer_writer = require("./buffer-writer")
local fire_listeners = require("./fire-listeners")
local middleware = require("./middleware")
local remotes = require("./remotes")
local types = require("./types")

local from = buffer_writer.from

return @native function(b: buffer, refs: { unknown }?, plr: Player?)
	local cursor = 0
	local totalLen = buffer.len(b)
	local sb = from(b)
	sb.references = refs or {}
	while cursor < totalLen do
		local id = buffer.readu8(b, cursor)
		local remo = remotes[id]
		cursor += 1
		local value, nc = (remo.schema.read :: (b: types.buffer_writer, c: number) -> (never, number))(sb, cursor)
		cursor += nc
		if remo.kind == "event" and remo.listeners ~= nil then
			if plr and not middleware.run_middleware_for(id, plr, b, refs) then
				continue
			end
			fire_listeners(remo.listeners, value, plr)
		end
	end
end
