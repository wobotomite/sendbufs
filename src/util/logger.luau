local RunService = game:GetService("RunService")

local constants = require(script.Parent.Parent.constants)
local is_debug = RunService:IsStudio() or (workspace:GetAttribute(constants.IS_DEBUG_ATTRIBUTE) == true)
local template = "[sendbufs]:"

function white(...: string)
	if is_debug then
		return
	end
	print(template, ...)
end

function orange(...: string)
	if is_debug then
		return
	end
	warn(template, ...)
end

function errorif(cond: boolean, str: string)
	if cond then
		error(str)
	end
end

return table.freeze({
	errorif = errorif,
	white = white,
	orange = orange,
})
