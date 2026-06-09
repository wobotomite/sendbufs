local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local constants = require(script.Parent.Parent.constants)
local validate = require(script.Parent.Parent.features.validate)
local connections = require(script.Parent.Parent.trackers.connections)
local ref_tracker = require(script.Parent.Parent.trackers["ref-tracker"])
local callbacks = require(script.Parent.Parent.util.callbacks)

local dump = require(script.Parent.Parent.util.dump)
local libtypes = require(script.Parent.Parent.util.libtypes)
local writer = require(script.Parent.Parent.util.writer)
local iter_and_convert = require(script.Parent.Parent.util["iter-and-convert"])
local large_buffer = require(script.Parent.Parent.util["large-buffer"])
local read_server = require(script.Parent.Parent.util["read-server"])
local read_server_remote_function = require(script.Parent.Parent.util["read-server-remote-function"])

local load = writer.load
local alloc = writer.alloc
local u8 = writer.u8
local export = writer.export

local __init = false

@native
function init<T>(t: T & {}, max_buffer_size: number?): libtypes.ReplicateServer<T>
	assert(not __init, "NETWORKING ALREADY STARTED")
	__init = true

	local max_buffer_size: number = max_buffer_size or constants.MAX_SERVER_BUFFER_SIZE

	local mt = table.freeze({ __mode = "k" })

	local players_reliable: { [Player]: libtypes.Buffer? } = {}
	local players_unreliable: { [Player]: libtypes.Buffer? } = {}

	local global_reliable = large_buffer()
	local global_unreliable = large_buffer()

	setmetatable(players_reliable, mt)
	setmetatable(players_unreliable, mt)

	local function append_all_reliable(id: number, writer: (any) -> (), data: any)
		load(global_reliable or large_buffer())
		alloc(1)
		u8(id)
		writer(data)
		global_reliable = export()
	end

	local function append_all_unreliable(id: number, writer: (any) -> (), data: any)
		load(global_unreliable or large_buffer())
		alloc(1)
		u8(id)
		writer(data)
		global_unreliable = export()
	end

	local function append_reliable(player: Player, id: number, writer: (any) -> (), data: any)
		load(players_reliable[player] or large_buffer())
		alloc(1)
		u8(id)
		writer(data)
		players_reliable[player] = export()
	end
	local function append_unreliable(player: Player, id: number, writer: (any) -> (), data: any)
		load(players_unreliable[player] or large_buffer())
		alloc(1)
		u8(id)
		writer(data)
		players_unreliable[player] = export()
	end

	local ReliableEvent = Instance.new("RemoteEvent")
	ReliableEvent.Name = constants.RELIABLE_EVENT_NAME
	local UnreliableEvent = Instance.new("UnreliableRemoteEvent")
	UnreliableEvent.Name = constants.UNRELIABLE_EVENT_NAME
	local RemoteFunction = Instance.new("RemoteFunction")
	RemoteFunction.Name = constants.REMOTE_FUNCTION

	local function create_object(intermediate: libtypes.Intermediate<any, any>): any
		if intermediate.__kind == "function" then
			local r: libtypes.ServerFunction = table.freeze({
				set_callback = function(self, callback)
					return callbacks.set(intermediate.id, callback)
				end,
				__kind = "function" :: "function",
				__T = nil :: never,
			})
			return r
		elseif intermediate.__kind == "event" then
			local r: libtypes.ServerRemote = table.freeze({
				connect = function(self, callback)
					return connections.add(intermediate.id, callback)
				end,
				fire_all = function(self, data)
					if intermediate.reliable then
						append_all_reliable(intermediate.id, intermediate.schema.write, data)
					else
						append_all_unreliable(intermediate.id, intermediate.schema.write, data)
					end
				end,
				fire = function(self, p, data)
					if intermediate.reliable then
						append_reliable(p, intermediate.id, intermediate.schema.write, data)
					else
						append_unreliable(p, intermediate.id, intermediate.schema.write, data)
					end
				end,
				__kind = "event" :: "event",
				__T = nil :: never,
			})
			return r
		end
		error("INVALID __KIND! EXPECTED function | event")
	end

	UnreliableEvent.OnServerEvent:Connect(function(player: Player, buf, ref)
		if not validate(buf, ref) then
			return
		end
		assert(
			max_buffer_size > buffer.len(buf),
			`BUFFER OF SIZE {buffer.len(buf)} EXCEEDS {max_buffer_size}B! SET THE SECOND PARAMETER OF THE INIT() FUNCTION TO A BIGGER VALUE!`
		)
		ref_tracker.set(ref)
		read_server(buf, player)
	end)
	ReliableEvent.OnServerEvent:Connect(function(player: Player, buf, ref)
		if not validate(buf, ref) then
			return
		end
		assert(
			max_buffer_size > buffer.len(buf),
			`BUFFER OF SIZE {buffer.len(buf)} EXCEEDS {max_buffer_size}B! SET THE SECOND PARAMETER OF THE INIT() FUNCTION TO A BIGGER VALUE!`
		)
		ref_tracker.set(ref)
		read_server(buf, player)
	end)

	RemoteFunction.OnServerInvoke = function(plr, b, ref): any
		if not validate(b, ref) then
			return false, nil, nil
		end
		ref_tracker.set(ref)
		return read_server_remote_function(plr, b)
	end

	RunService.Heartbeat:Connect(function()
		if global_reliable.cursor > 0 then
			local b, r = dump(global_reliable)
			ReliableEvent:FireAllClients(b, r)

			global_reliable.cursor = 0
			table.clear(global_reliable.references)
		end

		if global_unreliable.cursor > 0 then
			local b, r = dump(global_unreliable)
			UnreliableEvent:FireAllClients(b, r)

			global_unreliable.cursor = 0
			table.clear(global_unreliable.references)
		end

		for _, player in Players:GetPlayers() do
			local p_rel = players_reliable[player]
			local p_unrel = players_unreliable[player]

			if p_rel and p_rel.cursor > 0 then
				local b, r = dump(p_rel)
				ReliableEvent:FireClient(player, b, r)
				p_rel.cursor = 0
				table.clear(p_rel.references)
			end

			if p_unrel and p_unrel.cursor > 0 then
				local b, r = dump(p_unrel)
				UnreliableEvent:FireClient(player, b, r)
				p_unrel.cursor = 0
				table.clear(p_unrel.references)
			end
		end
	end)

	ReliableEvent.Parent = constants.EVENT_FOLDER
	UnreliableEvent.Parent = constants.EVENT_FOLDER
	RemoteFunction.Parent = constants.EVENT_FOLDER
	return iter_and_convert(t, create_object) :: never
end

return init
