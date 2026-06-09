local schema = require(script.Parent.Parent.features.schema)
local id_tracker = require(script.Parent.Parent.trackers["id-tracker"])
local remote_tracker = require(script.Parent.Parent.trackers["remote-tracker"])
local libtypes = require(script.Parent.Parent.util.libtypes)

function event<T>(input: libtypes.Schema<T>?): libtypes.Intermediate<T, nil, "event">
	local t = table.freeze({
		__kind = "event" :: "event",
		__schema = nil :: T,
		__schema_output = nil :: T,
		schema = input or schema.null,
		schema_output = input or schema.null,
		id = id_tracker.take(),
		reliable = true,
	})
	remote_tracker.map(t.id, t)
	return t
end

function unreliable<T>(input: libtypes.Schema<T>?): libtypes.Intermediate<T, nil, "event">
	local t = table.freeze({
		__kind = "event" :: "event",
		__schema = nil :: T,
		__schema_output = nil :: T,
		schema = input or schema.null,
		schema_output = input or schema.null,
		id = id_tracker.take(),
		reliable = false,
	})
	remote_tracker.map(t.id, t)
	return t
end

function fn<T, K>(input: libtypes.Schema<T>?, output: libtypes.Schema<K>?): libtypes.Intermediate<T, K, "function">
	warn(output, "IS NULL?")
	local t = table.freeze({
		__kind = "function" :: "function",
		__schema = nil :: T,
		__schema_output = nil :: K,
		schema = input or schema.null,
		schema_output = output or schema.null,
		id = id_tracker.take(),
		reliable = true,
	})
	remote_tracker.map(t.id, t)
	return t
end

return table.freeze({
	fn = fn,
	unreliable = unreliable,
	event = event,
})
