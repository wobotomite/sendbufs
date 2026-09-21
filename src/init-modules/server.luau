local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local constants = require(script.Parent.Parent.constants)
local validate = require(script.Parent.Parent.features.validate)
local connections = require(script.Parent.Parent.trackers.connections)
local ref_tracker = require(script.Parent.Parent.trackers["ref-tracker"])
local callbacks = require(script.Parent.Parent.util.callbacks)

local channel = require(script.Parent.Parent.util.channel)
local libtypes = require(script.Parent.Parent.util.libtypes)
local iter_and_convert = require(script.Parent.Parent.util["iter-and-convert"])
local read_server = require(script.Parent.Parent.util["read-server"])
local read_server_remote_function = require(script.Parent.Parent.util["read-server-remote-function"])
local remote_names = require(script.Parent.Parent.util["remote-names"])

local append = channel.append

local __init = false

local function init<T>(t: T & {}, max_buffer_size: number?): libtypes.ReplicateServer<T>
	assert(not __init, "NETWORKING ALREADY STARTED")
	__init = true

	local max_size: number = max_buffer_size or constants.MAX_SERVER_BUFFER_SIZE

	local reliable_name, unreliable_name, function_name = remote_names(game.JobId)

	local ReliableEvent = Instance.new("RemoteEvent")
	ReliableEvent.Name = reliable_name
	local UnreliableEvent = Instance.new("UnreliableRemoteEvent")
	UnreliableEvent.Name = unreliable_name
	local RemoteFunction = Instance.new("RemoteFunction")
	RemoteFunction.Name = function_name

	local global_reliable = channel.new(function(b, refs)
		ReliableEvent:FireAllClients(b, refs)
	end, math.huge)
	local global_unreliable = channel.new(function(b, refs)
		UnreliableEvent:FireAllClients(b, refs)
	end, constants.MAX_UNRELIABLE_SIZE)

	local players_reliable: { [Player]: libtypes.Channel } = {}
	local players_unreliable: { [Player]: libtypes.Channel } = {}
	-- players that left, so a late fire() does not open a channel nobody closes
	local gone: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any

	local function reliable_for(player: Player): libtypes.Channel?
		local found = players_reliable[player]
		if not found and not gone[player] then
			found = channel.new(function(b, refs)
				ReliableEvent:FireClient(player, b, refs)
			end, math.huge)
			players_reliable[player] = found
		end
		return found
	end

	local function unreliable_for(player: Player): libtypes.Channel?
		local found = players_unreliable[player]
		if not found and not gone[player] then
			found = channel.new(function(b, refs)
				UnreliableEvent:FireClient(player, b, refs)
			end, constants.MAX_UNRELIABLE_SIZE)
			players_unreliable[player] = found
		end
		return found
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
			local global = if intermediate.reliable then global_reliable else global_unreliable
			local channel_for: (Player) -> libtypes.Channel? = if intermediate.reliable
				then reliable_for
				else unreliable_for

			local r: libtypes.ServerRemote = table.freeze({
				connect = function(self, callback)
					return connections.add(id, callback)
				end,
				fire_all = function(self, data)
					append(global, id, write, data)
				end,
				fire = function(self, p, data)
					local target = channel_for(p)
					if target then
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

	local function size_error(len: number): string
		return `BUFFER OF SIZE {len} EXCEEDS {max_size}B! SET THE SECOND PARAMETER OF THE INIT() FUNCTION TO A BIGGER VALUE!`
	end

	local function on_event(player: Player, buf, ref)
		if not validate(buf, ref) then
			return
		end
		if buffer.len(buf) > max_size then
			error(size_error(buffer.len(buf)))
		end
		ref_tracker.set(ref)
		read_server(buf, player)
	end

	UnreliableEvent.OnServerEvent:Connect(on_event)
	ReliableEvent.OnServerEvent:Connect(on_event)

	RemoteFunction.OnServerInvoke = function(plr, b, ref): any
		if not validate(b, ref) then
			return false, nil, nil
		end
		if buffer.len(b) > max_size then
			-- raised on its own thread: an error in here would throw inside the client's invoke()
			task.spawn(error :: any, size_error(buffer.len(b)))
			return false, nil, nil
		end
		ref_tracker.set(ref)
		return read_server_remote_function(plr, b)
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

	ReliableEvent.Parent = constants.EVENT_FOLDER
	UnreliableEvent.Parent = constants.EVENT_FOLDER
	RemoteFunction.Parent = constants.EVENT_FOLDER
	return iter_and_convert(t, create_object) :: never
end

return init
