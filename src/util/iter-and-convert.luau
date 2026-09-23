local libtypes = require(script.Parent.libtypes)
local remote_names = require(script.Parent["remote-names"])
@native
local function iter_and_convert<T>(t: T & { [any]: any }, ctor: (libtypes.Intermediate<any, any, any>) -> any): (T, string)
	local result = {}
	-- "id path" for every remote, hashed below so the two sides can compare what they built
	local lines = {}

	local function recursive_index(origin: { [any]: any }, write_to: { [any]: any }, path: string)
		for i, v in pairs(origin) do
			local key = path .. tostring(i)
			if type(v) ~= "table" then
				error(`DEFINITIONS KEY {key} IS NOT A REMOTE OR A TABLE OF REMOTES`)
			end
			local is_schema = v.__kind and v.id

			if not is_schema then
				local new_table = {}
				write_to[i] = new_table
				recursive_index(v, new_table, key .. ".")
				continue
			end
			write_to[i] = ctor(v)
			table.insert(lines, `{v.id} {key}`)
		end
	end

	recursive_index(t, result, "")
	table.sort(lines)

	return table.freeze(result) :: any, remote_names.hash(table.concat(lines, "\n"))
end

return iter_and_convert
