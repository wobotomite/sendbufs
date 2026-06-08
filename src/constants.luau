return table.freeze({
	EVENT_TYPE = table.freeze({
		RELIABLE = 0,
		UNRELIABLE = 1,
	}),
	RELIABLE_EVENT_NAME = "_SB_RELIABLE",
	UNRELIABLE_EVENT_NAME = "_SB_UNRELIABLE",
	REMOTE_FUNCTION = "_SB_FUNCTION",

	-- INSTANCE_ID_ATTRIBUTE = "__SB_INSTANCE_ID",

	-- SERDES_WHITELIST = table.freeze({
	-- 	"Workspace",
	-- 	"ReplicatedStorage",
	-- }),

	MIN_BUFFER_SIZE = 16,
	SUPER_BUFFER_SIZE = 256,
})
