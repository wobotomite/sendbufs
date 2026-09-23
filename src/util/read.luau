--!native
--!optimize 2
local constants = require(script.Parent.Parent.constants)
local middleware = require(script.Parent.Parent.features.middleware)
local connections = require(script.Parent.Parent.trackers.connections)
local ref_tracker = require(script.Parent.Parent.trackers["ref-tracker"])
local remote_tracker = require(script.Parent.Parent.trackers["remote-tracker"])
local logger = require(script.Parent.logger)

local remotes = remote_tracker.get()
local run_middleware = middleware.run_middleware
local get_listeners = connections.get
local hold = connections.hold
local set_refs = ref_tracker.set

local MAX_MESSAGES = constants.MAX_MESSAGES

-- one packet of events; plr is who sent it on the server, nil on the client
return function(b: buffer, refs: { unknown }?, plr: Player?)
	-- a bad packet from a client is its own doing, from the server it is the game's
	local log = if plr then logger.orange else logger.red
	local cursor, size = 0, buffer.len(b)
	-- ids whose middleware refused this packet, so a packet of copies runs it once
	local refused: { [number]: true }? = nil

	for _ = 1, MAX_MESSAGES do
		if cursor >= size then
			return
		end
		local id = buffer.readu8(b, cursor)
		local remo = remotes[id]
		if not remo or remo.__kind ~= "event" then
			log(`INVALID EVENT ID! #{id}`)
			return
		end

		-- set before every read: a middleware or listener that yields lets another packet set its own
		set_refs(refs)
		-- nothing past a bad message can be trusted, so the rest of the packet is dropped
		local read, value, nc = pcall(remo.schema.read, b, cursor + 1)
		if not read then
			log(`MALFORMED PAYLOAD FOR EVENT #{id}: {value}`)
			return
		end
		cursor += nc + 1

		local listeners = get_listeners(id)
		if plr then
			if listeners and not (refused and refused[id]) then
				if run_middleware(id, plr) then
					for _, v in listeners do
						task.spawn(v, plr, value)
					end
				else
					refused = refused or {}
					refused[id] = true
				end
			end
		elseif listeners then
			for _, v in listeners do
				task.spawn(v, value)
			end
		elseif remo.reliable then
			hold(id, value)
		end
	end

	if cursor < size then
		log(`PACKET CARRIED OVER {MAX_MESSAGES} MESSAGES, THE REST WAS DROPPED`)
	end
end
