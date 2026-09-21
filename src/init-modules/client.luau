local RunService = game:GetService("RunService")

local constants = require(script.Parent.Parent.constants)
local connections = require(script.Parent.Parent.trackers.connections)
local ref_tracker = require(script.Parent.Parent.trackers["ref-tracker"])

local channel = require(script.Parent.Parent.util.channel)
local dump = require(script.Parent.Parent.util.dump)
local libtypes = require(script.Parent.Parent.util.libtypes)
local writer = require(script.Parent.Parent.util.writer)
local iter_and_convert = require(script.Parent.Parent.util["iter-and-convert"])
local read_client = require(script.Parent.Parent.util["read-client"])
local remote_names = require(script.Parent.Parent.util["remote-names"])
local small_buffer = require(script.Parent.Parent.util["small-buffer"])

local load = writer.load
local u8 = writer.u8
local export = writer.export
local append = channel.append

local __init = false

local function init<T>(t: T & {}): libtypes.ReplicateClient<T>
	assert(not __init, "NETWORKING ALREADY STARTED")
	__init = true

	-- the names hang off the JobId, which only studio never sets
	while game.JobId == "" and not RunService:IsStudio() do
		task.wait()
	end
	local reliable_name, unreliable_name, function_name = remote_names(game.JobId)

	local ReliableEvent = constants.EVENT_FOLDER:WaitForChild(reliable_name, math.huge) :: RemoteEvent
	local UnreliableEvent = constants.EVENT_FOLDER:WaitForChild(unreliable_name, math.huge) :: UnreliableRemoteEvent
	local RemoteFunction = constants.EVENT_FOLDER:WaitForChild(function_name, math.huge) :: RemoteFunction

	local function on_event(buf, ref)
		ref_tracker.set(ref)
		read_client(buf)
	end

	ReliableEvent.OnClientEvent:Connect(on_event)
	UnreliableEvent.OnClientEvent:Connect(on_event)

	local payload_reliable = channel.new(function(b, refs)
		ReliableEvent:FireServer(b, refs)
	end, math.huge)
	local payload_unreliable = channel.new(function(b, refs)
		UnreliableEvent:FireServer(b, refs)
	end, constants.MAX_UNRELIABLE_SIZE)

	local function invoke_fn(
		id: number,
		write: (any) -> (),
		reader: (buffer: buffer, cursor: number) -> (any, number),
		data: any
	): (boolean, any)
		load(small_buffer())
		u8(id)
		write(data)
		local success, nbuf, refs = RemoteFunction:InvokeServer(dump(export()))
		if success then
			ref_tracker.set(refs)
			return true, reader(nbuf, 0)
		end
		return false
	end

	local function create_object(intermediate: libtypes.Intermediate<any, any>): any
		local id = intermediate.id
		local write = intermediate.schema.write
		if intermediate.__kind == "function" then
			local read_output = intermediate.schema_output.read
			local r: libtypes.ClientFunction = table.freeze({
				invoke = function(self, data)
					return invoke_fn(id, write, read_output, data)
				end,
				__kind = "function" :: "function",
				__T = nil :: never,
			})
			return r
		elseif intermediate.__kind == "event" then
			local payload = if intermediate.reliable then payload_reliable else payload_unreliable
			local r: libtypes.ClientRemote = table.freeze({
				connect = function(self, callback)
					return connections.add(id, callback)
				end,
				fire = function(self, data)
					append(payload, id, write, data)
				end,
				__kind = "event" :: "event",
				__T = nil :: never,
			})
			return r
		end
		error("INVALID __KIND! EXPECTED function | event")
	end

	RunService.Heartbeat:Connect(channel.flush_all)

	return iter_and_convert(t, create_object) :: never
end

return init
