local RunService = game:GetService("RunService")

local constants = require(script.Parent.Parent.constants)
local schema = require(script.Parent.Parent.features.schema)
local connections = require(script.Parent.Parent.trackers.connections)
local ref_tracker = require(script.Parent.Parent.trackers["ref-tracker"])

local dump = require(script.Parent.Parent.util.dump)
local libtypes = require(script.Parent.Parent.util.libtypes)
local writer = require(script.Parent.Parent.util.writer)
local iter_and_convert = require(script.Parent.Parent.util["iter-and-convert"])
local large_buffer = require(script.Parent.Parent.util["large-buffer"])
local read_client = require(script.Parent.Parent.util["read-client"])
local small_buffer = require(script.Parent.Parent.util["small-buffer"])

local load = writer.load
local alloc = writer.alloc
local u8 = writer.u8
local export = writer.export

local __init = false

@native
function init<T>(t: T & {}): libtypes.ReplicateClient<T>
	assert(not __init, "NETWORKING ALREADY STARTED")
	__init = true
	local ReliableEvent = constants.EVENT_FOLDER:WaitForChild(constants.RELIABLE_EVENT_NAME, math.huge) :: RemoteEvent
	local UnreliableEvent =
		constants.EVENT_FOLDER:WaitForChild(constants.UNRELIABLE_EVENT_NAME, math.huge) :: UnreliableRemoteEvent
	local RemoteFunction = constants.EVENT_FOLDER:WaitForChild(constants.REMOTE_FUNCTION, math.huge) :: RemoteFunction

	ReliableEvent.OnClientEvent:Connect(function(buf, ref)
		ref_tracker.set(ref)
		read_client(buf)
	end)

	UnreliableEvent.OnClientEvent:Connect(function(buf, ref)
		ref_tracker.set(ref)
		read_client(buf)
	end)

	local payload_reliable = large_buffer()
	local payload_unreliable = large_buffer()

	local function append_reliable(id: number, writer: (any) -> (), data: any)
		load(payload_reliable)

		alloc(1)
		u8(id)
		writer(data)
		payload_reliable = export()
	end
	local function append_unreliable(id: number, writer: (any) -> (), data: any)
		load(payload_unreliable)

		alloc(1)
		u8(id)
		writer(data)
		payload_unreliable = export()
	end
	local function invoke_fn(
		id: number,
		writer: (any) -> (),
		reader: (buffer: buffer, cursor: number) -> (any, number),
		data: any
	): (boolean, any)
		local buf = small_buffer()
		load(buf)
		alloc(1)
		u8(id)
		writer(data)
		buf = export()
		local success, nbuf, refs = RemoteFunction:InvokeServer(dump(buf))
		if success then
			ref_tracker.set(refs)
			return true, reader(nbuf, 0)
		end
		return false
	end

	local function create_object(intermediate: libtypes.Intermediate<any, any>): any
		if intermediate.__kind == "function" then
			local r: libtypes.ClientFunction = table.freeze({
				invoke = function(self, data)
					return invoke_fn(intermediate.id, intermediate.schema.write, intermediate.schema_output.read, data)
				end,
				__kind = "function" :: "function",
				__T = nil :: never,
			})
			return r
		elseif intermediate.__kind == "event" then
			local r: libtypes.ClientRemote = table.freeze({
				connect = function(self, callback)
					return connections.add(intermediate.id, callback)
				end,
				fire = function(self, data)
					if intermediate.reliable then
						append_reliable(intermediate.id, intermediate.schema.write, data)
					else
						append_unreliable(intermediate.id, intermediate.schema.write, data)
					end
				end,
				__kind = "event" :: "event",
				__T = nil :: never,
			})
			return r
		end
		error("INVALID __KIND! EXPECTED function | event")
	end

	RunService.Heartbeat:Connect(function()
		if payload_reliable.cursor > 0 then
			local b, refs = dump(payload_reliable)
			ReliableEvent:FireServer(b, refs)
			payload_reliable.cursor = 0
			table.clear(payload_reliable.references)
		end
		if payload_unreliable.cursor > 0 then
			local b, r = dump(payload_unreliable)
			UnreliableEvent:FireServer(b, r)
			payload_unreliable.cursor = 0
			table.clear(payload_unreliable.references)
		end
	end)

	return iter_and_convert(t, create_object) :: never
end

return init
