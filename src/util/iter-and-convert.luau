local libtypes = require(script.Parent.libtypes)
@native
function iter_and_convert<T>(t: T & { [any]: any }, ctor: (libtypes.Intermediate) -> any): T
	local result = {}

	local function recursive_index(origin: { [any]: any }, write_to: { [any]: any })
		for i, v in pairs(origin) do
			local is_schema = v.__kind and v.id

			if not is_schema then
				local new_table = {}
				write_to[i] = new_table
				recursive_index(v, new_table)
			end
			write_to[i] = ctor(v)
		end
	end

	recursive_index(t, result)

	return table.freeze(result)
end

return iter_and_convert
