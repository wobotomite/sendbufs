return table.freeze({
	EVENT_TYPE = table.freeze({
		RELIABLE = 0,
		UNRELIABLE = 1,
	}),
	EVENT_FOLDER = game:GetService("ReplicatedStorage"),

	IS_DEBUG_ATTRIBUTE = "IS_DEBUG",

	VOID = "\135\135\174\174",

	-- INSTANCE_ID_ATTRIBUTE = "__SB_INSTANCE_ID",

	-- SERDES_WHITELIST = table.freeze({
	-- 	"Workspace",
	-- 	"ReplicatedStorage",
	-- }),

	MAX_SERVER_BUFFER_SIZE = 4096,
	-- UnreliableRemoteEvent drops payloads over 1000B, the rest is margin for the refs riding along
	MAX_UNRELIABLE_SIZE = 900,

	MIN_BUFFER_SIZE = 16,
	LARGE_BUFFER_SIZE = 256,
})
