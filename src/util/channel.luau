--!native
--!optimize 2
local constants = require(script.Parent.Parent.constants)
local dump = require(script.Parent.dump)
local libtypes = require(script.Parent.libtypes)
local logger = require(script.Parent.logger)
local writer = require(script.Parent.writer)

local load = writer.load
local u8 = writer.u8
local export = writer.export

local SHRINK_FLOOR = 4096
local MAX_REFS = 255

-- channels written to since the last flush_all
local dirty: { libtypes.Channel } = {}

local function new(send: (buffer, { unknown }?) -> (), limit: number): libtypes.Channel
	return {
		size = constants.LARGE_BUFFER_SIZE,
		inner = buffer.create(constants.LARGE_BUFFER_SIZE),
		cursor = 0,
		references = {},
		send = send,
		limit = limit,
	}
end

local function flush(channel: libtypes.Channel)
	local used = channel.cursor
	local b, refs = dump(channel)
	channel.cursor = 0
	channel.send(b, refs)
	table.clear(channel.references)

	-- one spike should not pin a huge buffer forever
	if channel.size > SHRINK_FLOOR and used * 8 < channel.size then
		channel.size //= 2
		channel.inner = buffer.create(channel.size)
	end
end

local function append(channel: libtypes.Channel, id: number, write: (any) -> (), data: any)
	local start, ref_start = channel.cursor, #channel.references
	load(channel)
	u8(id)
	write(data)
	export()

	local alone = start == 0
	if alone then
		dirty[#dirty + 1] = channel
	elseif channel.cursor > channel.limit or #channel.references > MAX_REFS then
		-- does not fit with what is queued: send that, then write this one again on its own
		local references = channel.references
		for i = #references, ref_start + 1, -1 do
			references[i] = nil
		end
		channel.cursor = start
		flush(channel)

		load(channel)
		u8(id)
		write(data)
		export()
		alone = true
	end

	if alone then
		if channel.cursor > channel.limit then
			logger.orange(
				`REMOTE #{id} WROTE {channel.cursor}B, OVER THE {channel.limit}B UNRELIABLE LIMIT! IT WILL BE DROPPED`
			)
		elseif #channel.references > MAX_REFS then
			logger.orange(`REMOTE #{id} WROTE {#channel.references} REFS, ONE PACKET CAN ONLY INDEX {MAX_REFS}`)
		end
	end
end

local function flush_all()
	for _, channel in dirty do
		if channel.cursor > 0 then
			flush(channel)
		end
	end
	table.clear(dirty)
end

return table.freeze({
	new = new,
	append = append,
	flush_all = flush_all,
})
