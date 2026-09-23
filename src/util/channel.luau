--!native
--!optimize 2
local constants = require(script.Parent.Parent.constants)
local dump = require(script.Parent.dump)
local libtypes = require(script.Parent.libtypes)
local logger = require(script.Parent.logger)
local writer = require(script.Parent.writer)

local message = writer.message

local SHRINK_FLOOR = 4096
local MAX_REFS = constants.MAX_REFS
local MAX_MESSAGES = constants.MAX_MESSAGES
local REF_BYTES = constants.REF_BYTES

-- channels written to since the last flush_all
local dirty: { libtypes.Channel } = {}
-- channels a flush left above SHRINK_FLOOR, dropped to it if they stay quiet until the next flush_all
local oversized: { libtypes.Channel } = {}

local function new(send: (buffer, { unknown }?) -> (), limit: number, reliable: boolean): libtypes.Channel
	return {
		inner = buffer.create(constants.LARGE_BUFFER_SIZE),
		cursor = 0,
		count = 0,
		references = {},
		send = send,
		limit = limit,
		reliable = reliable,
	}
end

local function flush(channel: libtypes.Channel)
	local used = channel.cursor
	if used == 0 then
		return
	end
	local b, refs = dump(channel)
	channel.cursor = 0
	channel.count = 0
	-- a send that throws (a cyclic table ref) loses this batch, not the channel
	local sent, why = pcall(channel.send :: any, b, refs)
	table.clear(channel.references)
	if not sent then
		logger.red(`DROPPED A {used}B BATCH, SENDING IT FAILED: {why}`)
	end

	-- one spike should not pin a huge buffer forever
	local size = buffer.len(channel.inner)
	if size > SHRINK_FLOOR then
		if used * 8 < size then
			channel.inner = buffer.create(size // 2)
		end
		oversized[#oversized + 1] = channel
	end
end

local function drop_refs_after(references: { unknown }, keep: number)
	for i = #references, keep + 1, -1 do
		references[i] = nil
	end
end

local function append(channel: libtypes.Channel, id: number, write: (any) -> (), data: any)
	local start, ref_start = channel.cursor, #channel.references
	-- a write that throws queues nothing, not even the refs it wrote before throwing
	local wrote, why = pcall(message :: any, channel, id, write, data)
	if not wrote then
		drop_refs_after(channel.references, ref_start)
		error(why, 0)
	end

	-- this message on its own, whatever is queued before it
	local bytes, refs = channel.cursor - start, #channel.references - ref_start
	local oversized = bytes + refs * REF_BYTES > channel.limit
	if refs > MAX_REFS or (oversized and not channel.reliable) then
		drop_refs_after(channel.references, ref_start)
		channel.cursor = start
		if refs > MAX_REFS then
			-- ref indices are one byte, past MAX_REFS they would point at the wrong refs
			error(`REMOTE #{id} WROTE {refs} REFS, ONE MESSAGE CAN CARRY {MAX_REFS}`)
		end
		-- the engine would drop it anyway
		logger.red(
			`DROPPED A {bytes}B UNRELIABLE MESSAGE WITH {refs} REFS FROM REMOTE #{id}, OVER THE {channel.limit}B LIMIT`
		)
		return
	end

	if start == 0 then
		dirty[#dirty + 1] = channel
	elseif
		channel.cursor + #channel.references * REF_BYTES > channel.limit
		or #channel.references > MAX_REFS
		or channel.count == MAX_MESSAGES
	then
		-- does not fit with what is queued: send that, then write this one again on its own
		drop_refs_after(channel.references, ref_start)
		channel.cursor = start
		flush(channel)

		message(channel, id, write, data)
	end
	channel.count += 1

	if oversized then
		logger.red(
			`REMOTE #{id} WROTE A {bytes}B MESSAGE WITH {refs} REFS, OVER THE {channel.limit}B LIMIT! IT WILL LIKELY BE DROPPED`
		)
	end
end

local function flush_all()
	for _, channel in oversized do
		if channel.cursor == 0 and buffer.len(channel.inner) > SHRINK_FLOOR then
			channel.inner = buffer.create(SHRINK_FLOOR)
		end
	end
	table.clear(oversized)
	for _, channel in dirty do
		flush(channel)
	end
	table.clear(dirty)
end

return table.freeze({
	new = new,
	append = append,
	-- sends what is queued now, for callers keeping order with another channel
	flush = flush,
	flush_all = flush_all,
})
