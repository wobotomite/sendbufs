local constants = require(script.Parent.Parent.constants)

local libtypes = require(script.Parent.libtypes)
return @native function(): libtypes.Buffer
	return {
		size = constants.MIN_BUFFER_SIZE,
		inner = buffer.create(constants.MIN_BUFFER_SIZE),
		cursor = 0,
		references = {},
	}
end
