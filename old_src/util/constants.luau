return table.freeze({
	EVENT_TYPE = table.freeze({
		RELIABLE = 0,
		UNRELIABLE = 1,
	}),
	RELIABLE_EVENT_NAME = "_sb_reliable",
	UNRELIABLE_EVENT_NAME = "_sb_unreliable",
	REMOTE_FUNCTION = "_sb_function",

	MIN_BUFFER_SIZE = 16,
	SUPER_BUFFER_SIZE = 256,
})
