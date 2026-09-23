local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local constants = require(script.Parent.Parent.constants)
local validate = require(script.Parent.Parent.features.validate)
local connections = require(script.Parent.Parent.trackers.connections)
local callbacks = require(script.Parent.Parent.util.callbacks)

local channel = require(script.Parent.Parent.util.channel)
local libtypes = require(script.Parent.Parent.util.libtypes)
local logger = require(script.Parent.Parent.util.logger)
local iter_and_convert = require(script.Parent.Parent.util["iter-and-convert"])
local read = require(script.Parent.Parent.util.read)
local read_server_remote_function = require(script.Parent.Parent.util["read-server-remote-function"])
local remote_names = require(script.Parent.Parent.util["remote-names"])

local append = channel.append
local flush = channel.flush

local __init = false

local function init<T>(t: T & {}, max_buffer_size: number?): libtypes.ReplicateServer<T>
	assert(not __init, "NETWORKING ALREADY STARTED")

	local max_size: number = max_buffer_size or constants.MAX_SERVER_BUFFER_SIZE

	local reliable_name, unreliable_name, function_name = remote_names.names(game.JobId)

	local ReliableEvent = Instance.new("RemoteEvent")
	ReliableEvent.Name = reliable_name
	local UnreliableEvent = Instance.new("UnreliableRemoteEvent")
	UnreliableEvent.Name = unreliable_name
	local RemoteFunction = Instance.new("RemoteFunction")
	RemoteFunction.Name = function_name

	local global_reliable = channel.new(function(b, refs)
		ReliableEvent:FireAllClients(b, refs)
	end, math.huge, true)
	local global_unreliable = channel.new(function(b, refs)
		UnreliableEvent:FireAllClients(b, refs)
	end, constants.MAX_UNRELIABLE_SIZE, false)

	-- players that left, so a late fire() does not open a channel nobody closes
	local gone: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any

	local function per_player(fire: (Player, buffer, { unknown }?) -> (), limit: number, reliable: boolean)
		local lanes: { [Player]: libtypes.Channel } = {}
		local function lane_for(player: Player): libtypes.Channel?
			local found = lanes[player]
			-- a Player that left has no parent, which still holds once gone has let go of it
			if not found and player.Parent == Players and not gone[player] then
				found = channel.new(function(b, refs)
					fire(player, b, refs)
				end, limit, reliable)
				lanes[player] = found
			end
			return found
		end
		return lanes, lane_for
	end

	local players_reliable, reliable_for = per_player(function(player, b, refs)
		ReliableEvent:FireClient(player, b, refs)
	end, math.huge, true)
	local players_unreliable, unreliable_for = per_player(function(player, b, refs)
		UnreliableEvent:FireClient(player, b, refs)
	end, constants.MAX_UNRELIABLE_SIZE, false)

	-- fire and fire_all keep one order: a reliable lane is sent early before the other one takes a message,
	-- so only one side ever has messages waiting
	local last_global = false
	local function to_all()
		if not last_global then
			for _, lane in players_reliable do
				flush(lane)
			end
			last_global = true
		end
	end
	local function to_players()
		if last_global then
			flush(global_reliable)
			last_global = false
		end
	end

	local function create_object(intermediate: libtypes.Intermediate<any, any>): any
		local id = intermediate.id
		if intermediate.__kind == "function" then
			local r: libtypes.ServerFunction = table.freeze({
				set_callback = function(self, callback)
					return callbacks.set(id, callback)
				end,
				__kind = "function" :: "function",
				__T = nil :: never,
			})
			return r
		elseif intermediate.__kind == "event" then
			local write = intermediate.schema.write
			local reliable = intermediate.reliable
			local global = if reliable then global_reliable else global_unreliable
			local channel_for: (Player) -> libtypes.Channel? = if reliable then reliable_for else unreliable_for

			local r: libtypes.ServerRemote = table.freeze({
				connect = function(self, callback)
					return connections.add(id, callback)
				end,
				fire_all = function(self, data)
					if reliable then
						to_all()
					end
					append(global, id, write, data)
				end,
				fire = function(self, p, data)
					local target = channel_for(p)
					if target then
						if reliable then
							to_players()
						end
						append(target, id, write, data)
					end
				end,
				__kind = "event" :: "event",
				__T = nil :: never,
			})
			return r
		end
		error("INVALID __KIND! EXPECTED function | event")
	end

	-- before anything is started, so bad definitions leave nothing behind
	local converted, signature = iter_and_convert(t, create_object)
	__init = true

	-- logged, not raised: any client can send anything, as often as it likes
	local function accept(buf: any, ref: any): boolean
		if not validate(buf, ref) then
			logger.orange("DROPPED AN INVALID PACKET")
			return false
		end
		local len = buffer.len(buf)
		if len > max_size then
			logger.orange(
				`BUFFER OF SIZE {len} EXCEEDS {max_size}B! PASS A BIGGER SIZE AS THE SECOND ARGUMENT OF create_server`
			)
			return false
		end
		return true
	end

	local function on_event(player: Player, buf: any, ref: any)
		if accept(buf, ref) then
			read(buf, ref, player)
		end
	end

	UnreliableEvent.OnServerEvent:Connect(on_event)
	ReliableEvent.OnServerEvent:Connect(on_event)

	RemoteFunction.OnServerInvoke = function(plr, b, ref): any
		if not accept(b, ref) then
			return false, nil, nil
		end
		local ok, out, refs = read_server_remote_function(plr, b, ref)
		-- the reply must not overtake events fired to this player before it
		flush(global_reliable)
		local lane = players_reliable[plr]
		if lane then
			flush(lane)
		end
		return ok, out, refs
	end

	Players.PlayerRemoving:Connect(function(player)
		gone[player] = true
		local reliable, unreliable = players_reliable[player], players_unreliable[player]
		if reliable then
			reliable.cursor = 0
			players_reliable[player] = nil
		end
		if unreliable then
			unreliable.cursor = 0
			players_unreliable[player] = nil
		end
	end)

	RunService.Heartbeat:Connect(channel.flush_all)

	-- read by the client: its batches must fit max_size, and its ids must match these
	ReliableEvent:SetAttribute(constants.MAX_SIZE_ATTRIBUTE, max_size)
	ReliableEvent:SetAttribute(constants.SIGNATURE_ATTRIBUTE, signature)

	ReliableEvent.Parent = constants.EVENT_FOLDER
	UnreliableEvent.Parent = constants.EVENT_FOLDER
	RemoteFunction.Parent = constants.EVENT_FOLDER
	return converted :: never
end

return init
