--!native
--!optimize 2
local middleware = require(script.Parent.Parent.features.middleware)
local remote_tracker = require(script.Parent.Parent.trackers["remote-tracker"])
local callbacks = require(script.Parent.callbacks)
local dump = require(script.Parent.dump)
local logger = require(script.Parent.logger)
local writer = require(script.Parent.writer)
local small_buffer = require(script.Parent["small-buffer"])

local remotes = remote_tracker.get()

return function(plr: Player, b: buffer): (boolean, buffer?, { unknown }?)
	local id = buffer.readu8(b, 0)
	local remo = remotes[id]

	if not remo or remo.__kind ~= "function" then
		logger.orange(`INVALID FUNCTION ID! #{id}`)
		return false, nil, nil
	end

	local read, value = pcall(remo.schema.read, b, 1)
	if not read then
		logger.orange(`MALFORMED PAYLOAD FOR FUNCTION #{id}: {value}`)
		return false, nil, nil
	end

	local callback = callbacks.get(id)

	if not callback then
		logger.orange(`UNHANDLED REMOTE FUNCTION! #{id}`)
		return false, nil, nil
	end

	if not middleware.run_middleware(id, plr) then
		return false, nil, nil
	end

	local ran, success, res = pcall(callback, plr, value)
	if not ran then
		logger.orange(`CALLBACK FAILED: {success}`)
		return false, nil, nil
	end
	if not success then
		return false, nil, nil
	end

	writer.load(small_buffer())
	local wrote, why = pcall(remo.schema_output.write :: any, res)
	if not wrote then
		logger.orange(`FUNCTION #{id} RETURNED A VALUE ITS SCHEMA CANNOT WRITE: {why}`)
		return false, nil, nil
	end
	return true, dump(writer.export())
end
