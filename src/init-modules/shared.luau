local schema = require(script.Parent.Parent.features.schema)
local remote_tracker = require(script.Parent.Parent.trackers["remote-tracker"])
local libtypes = require(script.Parent.Parent.util.libtypes)

-- a schema left out is nil, not a T nothing constrains, so a payload given for it is a type error
type Event =
	(<T>(input: libtypes.Schema<T>) -> libtypes.Intermediate<T, nil, "event">)
	& (() -> libtypes.Intermediate<nil, nil, "event">)
type Function =
	(<T, K>(input: libtypes.Schema<T>, output: libtypes.Schema<K>) -> libtypes.Intermediate<T, K, "function">)
	& (<K>(input: nil, output: libtypes.Schema<K>) -> libtypes.Intermediate<nil, K, "function">)
	& (<T>(input: libtypes.Schema<T>) -> libtypes.Intermediate<T, nil, "function">)
	& (() -> libtypes.Intermediate<nil, nil, "function">)

local function event<T>(input: libtypes.Schema<T>?): libtypes.Intermediate<T, nil, "event">
	local t = table.freeze({
		__kind = "event" :: "event",
		__schema = nil :: T,
		__schema_output = nil,
		schema = input or schema.null,
		id = remote_tracker.take(),
		reliable = true,
	})
	remote_tracker.map(t.id, t)
	return t
end

local function unreliable<T>(input: libtypes.Schema<T>?): libtypes.Intermediate<T, nil, "event">
	local t = table.freeze({
		__kind = "event" :: "event",
		__schema = nil :: T,
		__schema_output = nil,
		schema = input or schema.null,
		id = remote_tracker.take(),
		reliable = false,
	})
	remote_tracker.map(t.id, t)
	return t
end

local function fn<T, K>(input: libtypes.Schema<T>?, output: libtypes.Schema<K>?): libtypes.Intermediate<T, K, "function">
	local t = table.freeze({
		__kind = "function" :: "function",
		__schema = nil :: T,
		__schema_output = nil :: K,
		schema = input or schema.null,
		schema_output = output or schema.null,
		id = remote_tracker.take(),
	})
	remote_tracker.map(t.id, t)
	return t
end

return table.freeze({
	fn = fn :: Function,
	unreliable = unreliable :: Event,
	event = event :: Event,
})
