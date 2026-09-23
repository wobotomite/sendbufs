return table.freeze({
	EVENT_FOLDER = game:GetService("ReplicatedStorage"),

	IS_DEBUG_ATTRIBUTE = "IS_DEBUG",
	-- set by the server on its reliable remote, checked by the client
	MAX_SIZE_ATTRIBUTE = "MAX_SIZE",
	SIGNATURE_ATTRIBUTE = "SIGNATURE",

	MAX_SERVER_BUFFER_SIZE = 4096,
	-- UnreliableRemoteEvent drops calls over 1000B, refs included, the rest is margin
	MAX_UNRELIABLE_SIZE = 900,
	-- what one ref is counted as against a batch's limit
	REF_BYTES = 8,
	-- ref indices are one byte
	MAX_REFS = 255,
	-- per inbound packet, so one packet can't spawn thousands of listener threads
	MAX_MESSAGES = 256,

	MIN_BUFFER_SIZE = 16,
	LARGE_BUFFER_SIZE = 256,
})
