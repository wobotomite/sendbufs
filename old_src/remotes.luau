local types = require("./types")

type reflist = { types.t_event<never> | types.t_fn<never, never> }
local refs: reflist = {}
return refs
