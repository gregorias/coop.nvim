--- Utilities for working with coroutines.
local M = {}

--- Executes a plain coroutine function in a protected mode.
---
--- This is also a plain coroutine function.
---
--- copcall is a coroutine alternative to pcall. pcall is not suitable for coroutines, because yields can’t cross a
--- pcall. copcall goes around that restriction by using coroutine.resume.
---
---@param f_co function A plain coroutine function to execute.
---@return boolean success Whether the coroutine function executed successfully.
---@return ... The results of the coroutine function.
M.copcall = function(f_co, ...)
	local thread = coroutine.create(f_co)
	local results = { coroutine.resume(thread, ...) }
	while true do
		if not results[1] then
			return false, results[2]
		end

		if coroutine.status(thread) == "dead" then
			return true, unpack(results, 2)
		end

		coroutine.yield()
		results = { coroutine.resume(thread) }
	end
end

return M
