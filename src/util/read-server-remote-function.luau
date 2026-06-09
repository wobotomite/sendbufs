local middleware = require(script.Parent.Parent.features.middleware)
local ref_tracker = require(script.Parent.Parent.trackers["ref-tracker"])
local remote_tracker = require(script.Parent.Parent.trackers["remote-tracker"])
local callbacks = require(script.Parent.callbacks)
local dump = require(script.Parent.dump)
local libtypes = require(script.Parent.libtypes)
local logger = require(script.Parent.logger)
local writer = require(script.Parent.writer)
local small_buffer = require(script.Parent["small-buffer"])

return @native function(plr: Player, b: buffer): (boolean, buffer?, { unknown }?)
	local sb: libtypes.Buffer = {
		inner = b,
		references = ref_tracker.get() or {},
		size = buffer.len(b),
		cursor = 0,
	}
	while sb.cursor < sb.size do
		local id = buffer.readu8(b, sb.cursor)
		local remo = remote_tracker.get()[id]

		if remo.__kind ~= "function" then
			logger.orange(`INVALID FUNCTION ID! #{id}`)
			return false, nil, nil
		end

		sb.cursor += 1
		local value, nc = remo.schema.read(sb.inner, sb.cursor)
		sb.cursor += nc

		local callback = callbacks.get(id)

		if not callback then
			logger.orange(`UNHANDLED REMOTE FUNCTION! #{id}`)
			return false, nil, nil
		end

		if not middleware.run_middleware(id, plr) then
			return false, nil, nil
		end
		local success, res = pcall(callback, plr, value)

		if not success then
			logger.orange(`CALLBACK FAILED: {res}`)
			return false, nil, nil
		end

		local buf = small_buffer()
		writer.load(buf)
		remo.schema_output.write(res)
		local r, refs = dump(writer.export())
		return true, r, refs
	end
	return false, nil, nil
end
