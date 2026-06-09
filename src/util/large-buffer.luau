local constants = require(script.Parent.Parent.constants)

local libtypes = require(script.Parent.libtypes)
return @native function(): libtypes.Buffer
	return {
		size = constants.LARGE_BUFFER_SIZE,
		inner = buffer.create(constants.LARGE_BUFFER_SIZE),
		cursor = 0,
		references = {},
	}
end
