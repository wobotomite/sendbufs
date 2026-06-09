local RunService = game:GetService("RunService")
local is_debug = RunService:IsStudio()
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

function errorif(cond: boolean, ...: string)
	if cond then
		error(...)
	end
end

return table.freeze({
	errorif = errorif,
	white = white,
	red = red,
	orange = orange,
})
