local RunService = game:GetService("RunService")

local constants = require(script.Parent.Parent.constants)
local template = "[sendbufs]:"

-- read on every call so the attribute can be flipped on a live server
local function is_debug(): boolean
	return RunService:IsStudio() or workspace:GetAttribute(constants.IS_DEBUG_ATTRIBUTE) == true
end

-- for what any client can cause at will, so only shown in debug
local function orange(...: string)
	if not is_debug() then
		return
	end
	warn(template, ...)
end

-- for mistakes in the game's own code, always shown, without stopping the caller
local function red(...: string)
	task.spawn(error :: (string, number) -> (), table.concat({ template, ... }, " "), 0)
end

return table.freeze({
	orange = orange,
	red = red,
})
