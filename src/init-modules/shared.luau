local libtypes = require(script.Parent.Parent.util.libtypes)
function event<T>(input: libtypes.Schema<T>): libtypes.Intermediate<T, "event">
	return nil :: never
end

function _function<T>(input: libtypes.Schema<T>): libtypes.Intermediate<T, "function">
	return nil :: never
end

return table.freeze({
	["fn"] = _function,
	["event"] = event,
})
