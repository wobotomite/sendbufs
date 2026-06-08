local RunService = game:GetService("RunService")
local is_debug = RunService:IsStudio()
local template = "[sendbufs]: %s"

function white(...: string)
	if is_debug then
		return
	end
	print(template:format(table.concat({ ... }, ", ")))
end

function red(...: string)
	error(template:format(table.concat({ ... }, ", ")))
end

function orange(...: string)
	if is_debug then
		return
	end
	warn(template:format(table.concat({ ... }, ", ")))
end

function errorif(cond: boolean, ...: string)
	if cond then
		red(...)
	end
end

return table.freeze({
	errorif = errorif,
	white = white,
	red = red,
	orange = orange,
})
