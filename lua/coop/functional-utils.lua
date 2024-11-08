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
		local pack = require("coop.table-utils").pack
		local unpack = require("coop.table-utils").unpack_packed
		local args = pack(...)
		return f(unpack(shift_f(args, args.n)))
	end
end

return M
