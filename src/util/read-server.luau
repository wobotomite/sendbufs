--!native
--!optimize 2
local middleware = require(script.Parent.Parent.features.middleware)
local connections = require(script.Parent.Parent.trackers.connections)
local remote_tracker = require(script.Parent.Parent.trackers["remote-tracker"])
local logger = require(script.Parent.logger)

local remotes = remote_tracker.get()
local run_middleware = middleware.run_middleware
local get_listeners = connections.get

-- the id being read, for the log line below
local reading = 0

local function read_packet(b: buffer, plr: Player)
	local cursor, size = 0, buffer.len(b)
	while cursor < size do
		local id = buffer.readu8(b, cursor)
		local remo = remotes[id]
		if not remo or remo.__kind ~= "event" then
			logger.orange(`INVALID EVENT ID! #{id}`)
			return
		end

		reading = id
		local value, nc = remo.schema.read(b, cursor + 1)
		cursor += nc + 1

		local listeners = get_listeners(id)
		if listeners ~= nil and run_middleware(id, plr) then
			for _, v in listeners do
				task.spawn(v, plr, value)
			end
		end
	end
end

-- one pcall a packet: nothing past a bad message can be trusted, so the rest of it is dropped
return function(b: buffer, plr: Player)
	local read, why = pcall(read_packet :: any, b, plr)
	if not read then
		logger.orange(`MALFORMED PAYLOAD FOR EVENT #{reading}: {why}`)
	end
end
