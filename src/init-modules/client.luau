local libtypes = require(script.Parent.Parent.util.libtypes)

@native
function init<T>(t: T & {}): libtypes.ReplicateClient<T>
	return nil :: never
end

return init
