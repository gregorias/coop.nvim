--- Functional utilities for Lua.
local M = {}

--- Returns a function that shifts the parameters of the given function.
---
---@param f function The function to shift the parameters of.
---@param shift_f? function The function that shifts the parameters. `shift_left` by default.
---@return function
M.shift_parameters = function(f, shift_f)
	shift_f = shift_f or require("coop.table-utils").shift_left
	return function(...)
		return f(unpack(shift_f({ ... })))
	end
end

return M
