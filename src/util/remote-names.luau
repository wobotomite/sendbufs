-- names hashed from the JobId: both sides get the same ones without a handshake, and no two servers share them

local function fnv1a(text: string, hash: number): number
	for i = 1, #text do
		hash = bit32.bxor(hash, string.byte(text, i))
		-- hash * 16777619, split so it stays inside a double
		hash = (bit32.lshift(hash, 24) + hash * 403) % 4294967296
	end
	return hash
end

local function guid(text: string): string
	local a = fnv1a(text, 2166136261)
	local b = fnv1a(text, a)
	local c = fnv1a(text, b)
	local d = fnv1a(text, c)
	return string.format("%08x-%04x-%04x-%04x-%04x%08x", a, b // 65536, b % 65536, c // 65536, c % 65536, d)
end

-- studio has no job, and its two sides spell that differently: the server reads "", the client this
local NO_JOB = "00000000-0000-0000-0000-000000000000"

local function names(job_id: string): (string, string, string)
	if job_id == NO_JOB then
		job_id = ""
	end
	return guid("reliable" .. job_id), guid("unreliable" .. job_id), guid("function" .. job_id)
end

return table.freeze({
	names = names,
	-- also hashes the definitions, so the client can check it built the same ids as the server
	hash = guid,
})
