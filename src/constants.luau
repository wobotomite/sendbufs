return table.freeze({
	EVENT_TYPE = table.freeze({
		RELIABLE = 0,
		UNRELIABLE = 1,
	}),
	RELIABLE_EVENT_NAME = "_SB_RELIABLE",
	UNRELIABLE_EVENT_NAME = "_SB_UNRELIABLE",
	REMOTE_FUNCTION = "_SB_FUNCTION",

	EVENT_FOLDER = game:GetService("ReplicatedStorage"),

	IS_DEBUG_ATTRIBUTE = "IS_DEBUG"

	-- INSTANCE_ID_ATTRIBUTE = "__SB_INSTANCE_ID",

	-- SERDES_WHITELIST = table.freeze({
	-- 	"Workspace",
	-- 	"ReplicatedStorage",
	-- }),

	MAX_SERVER_BUFFER_SIZE = 4096,

	MIN_BUFFER_SIZE = 16,
	LARGE_BUFFER_SIZE = 256,
})
