local RunService = game:GetService("RunService")

local constants = require(script.Parent.Parent.constants)
local connections = require(script.Parent.Parent.trackers.connections)
local ref_tracker = require(script.Parent.Parent.trackers["ref-tracker"])

local channel = require(script.Parent.Parent.util.channel)
local dump = require(script.Parent.Parent.util.dump)
local libtypes = require(script.Parent.Parent.util.libtypes)
local logger = require(script.Parent.Parent.util.logger)
local writer = require(script.Parent.Parent.util.writer)
local iter_and_convert = require(script.Parent.Parent.util["iter-and-convert"])
local read = require(script.Parent.Parent.util.read)
local remote_names = require(script.Parent.Parent.util["remote-names"])
local small_buffer = require(script.Parent.Parent.util["small-buffer"])

local append = channel.append

local __init = false

local function init<T>(t: T & {}): libtypes.ReplicateClient<T>
	assert(not __init, "NETWORKING ALREADY STARTED")

	-- found below; nothing can fire before init returns, so the channels only reach them after that
	local ReliableEvent: RemoteEvent
	local UnreliableEvent: UnreliableRemoteEvent
	local RemoteFunction: RemoteFunction
	-- what the server accepts from one call, read from its remote
	local max_size = constants.MAX_SERVER_BUFFER_SIZE

	local payload_reliable = channel.new(function(b, refs)
		ReliableEvent:FireServer(b, refs)
	end, max_size, true)
	local payload_unreliable = channel.new(function(b, refs)
		UnreliableEvent:FireServer(b, refs)
	end, constants.MAX_UNRELIABLE_SIZE, false)

	local function invoke_fn(
		id: number,
		write: (any) -> (),
		reader: (buffer: buffer, cursor: number) -> (any, number),
		data: any
	): (boolean, any)
		local b = small_buffer()
		writer.message(b, id, write, data)
		local refs = #b.references
		if refs > constants.MAX_REFS then
			-- ref indices are one byte, past MAX_REFS they would point at the wrong refs
			error(`REMOTE #{id} WROTE {refs} REFS, ONE MESSAGE CAN CARRY {constants.MAX_REFS}`)
		end
		if b.cursor > max_size then
			logger.red(`REMOTE #{id} WROTE A {b.cursor}B INVOKE, OVER THE SERVER'S {max_size}B LIMIT`)
			return false, nil
		end
		-- events fired before the call reach the server before it
		channel.flush(payload_reliable)
		local success, nbuf, nrefs = RemoteFunction:InvokeServer(dump(b))
		if success then
			ref_tracker.set(nrefs)
			return true, (reader(nbuf, 0))
		end
		return false, nil
	end

	local function create_object(intermediate: libtypes.Intermediate<any, any>): any
		local id = intermediate.id
		local write = intermediate.schema.write
		if intermediate.__kind == "function" then
			local read_output = (intermediate.schema_output :: libtypes.Schema<any>).read
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

	-- before anything waits, so bad definitions throw at once and leave nothing behind
	local converted, signature = iter_and_convert(t, create_object)
	__init = true

	-- the names hang off the JobId, which can be read before it replicates, so they are worked out again each frame
	local reliable_name, unreliable_name, function_name = remote_names.names(game.JobId)
	local waited = 0
	while not constants.EVENT_FOLDER:FindFirstChild(reliable_name) do
		local was = waited
		waited += task.wait()
		if was < 5 and waited >= 5 then
			logger.red(`NO REMOTES FOR JOBID "{game.JobId}" AFTER 5S, IS create_server RUNNING ON THE SERVER?`)
		end
		reliable_name, unreliable_name, function_name = remote_names.names(game.JobId)
	end

	ReliableEvent = constants.EVENT_FOLDER:WaitForChild(reliable_name) :: RemoteEvent
	UnreliableEvent = constants.EVENT_FOLDER:WaitForChild(unreliable_name) :: UnreliableRemoteEvent
	RemoteFunction = constants.EVENT_FOLDER:WaitForChild(function_name) :: RemoteFunction

	max_size = (ReliableEvent:GetAttribute(constants.MAX_SIZE_ATTRIBUTE) :: number?) or max_size
	payload_reliable.limit = max_size
	payload_unreliable.limit = math.min(constants.MAX_UNRELIABLE_SIZE, max_size)
	if ReliableEvent:GetAttribute(constants.SIGNATURE_ATTRIBUTE) ~= signature then
		logger.red(
			"THE SERVER AND THE CLIENT BUILT DIFFERENT REMOTES, SO MESSAGES CAN REACH THE WRONG ONE! CREATE THE SAME REMOTES IN THE SAME ORDER ON BOTH SIDES"
		)
	end

	ReliableEvent.OnClientEvent:Connect(read)
	UnreliableEvent.OnClientEvent:Connect(read)

	RunService.Heartbeat:Connect(channel.flush_all)

	return converted :: never
end

return init
