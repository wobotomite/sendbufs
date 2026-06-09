local connections = require(script.Parent.Parent.trackers.connections)
local ref_tracker = require(script.Parent.Parent.trackers["ref-tracker"])
local remote_tracker = require(script.Parent.Parent.trackers["remote-tracker"])

local libtypes = require(script.Parent.libtypes)
return @native function(b: buffer)
	local sb: libtypes.Buffer = {
		inner = b,
		references = ref_tracker.get() or {},
		size = buffer.len(b),
		cursor = 0,
	}
	while sb.cursor < sb.size do
		local id = buffer.readu8(b, sb.cursor)
		local remo = remote_tracker.get()[id]
		local listeners = connections.get(id)
		sb.cursor += 1
		local value, nc = remo.schema.read(sb.inner, sb.cursor)
		sb.cursor += nc
		if remo.__kind == "event" and listeners ~= nil then
			for i, v in listeners do
				task.spawn(v, value)
			end
		end
	end
end
