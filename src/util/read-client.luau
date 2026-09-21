--!native
--!optimize 2
local connections = require(script.Parent.Parent.trackers.connections)
local remote_tracker = require(script.Parent.Parent.trackers["remote-tracker"])
local logger = require(script.Parent.logger)

local remotes = remote_tracker.get()
local get_listeners = connections.get

return function(b: buffer)
	local cursor, size = 0, buffer.len(b)
	while cursor < size do
		local id = buffer.readu8(b, cursor)
		local remo = remotes[id]
		if not remo or remo.__kind ~= "event" then
			logger.orange(`INVALID EVENT ID! #{id}`)
			return
		end

		local value, nc = remo.schema.read(b, cursor + 1)
		cursor += nc + 1

		local listeners = get_listeners(id)
		if listeners ~= nil then
			for _, v in listeners do
				task.spawn(v, value)
			end
		end
	end
end
