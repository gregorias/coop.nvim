--- Table utilities.
local M = {}

--- Packs a vararg expression into a table.
---
---@param ... ...
---@return table
M.pack = function(...)
	-- selene: allow(mixed_table)
	return { n = select("#", ...), ... }
end

--- Shifts elements of a list to the left.
---
---@param t table The list to shift.
---@return table list
M.shift_left = function(t)
	if #t == 0 then
		return t
	end

	local first = t[1]
	for i = 1, #t - 1 do
		t[i] = t[i + 1]
	end
	t[#t] = first

	return t
end

--- Shifts elements of a list to the right.
---
---@param t table The list to shift.
---@return table list
M.shift_right = function(t)
	if #t == 0 then
		return t
	else
		table.insert(t, 1, table.remove(t, #t))
		return t
	end
end

return M
