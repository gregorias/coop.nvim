--- Utilities for working with coroutines.
local M = {}

local pack = require("coop.table-utils").pack

-- ADR: cb_to_co’s argument accepts a callback as its first argument.
-- This keeps the implementation straightforward and focused.

-- ADR: Keep cb_to_co and cb_to_tf. One of Coop’s purposes is educational.
-- Keep `cb_to_co` to show how a simplified conversion looks like.

--- Converts a callback-based function to a coroutine function.
---
--- If the callback is called asynchronously, then the coroutine function yields exactly once and is resumed by whoever
--- calls the callback. If the callback is called synchronously, then the coroutine function returns immediately.
---
---@param  f function The function to convert. The callback needs to be its first argument.
---@return function co A coroutine function. Accepts the same arguments as f without the callback.
---                    Returns what f has passed to the callback.
M.cb_to_co = function(f)
	local f_co = function(...)
		local this = coroutine.running()
		assert(this ~= nil, "The result of cb_to_tf must be called within a task.")

		local f_status = "running"
		local f_ret = pack()
		-- f needs to have the callback as its first argument, because varargs passing doesn’t work otherwise.
		f(function(...)
			f_status = "done"
			f_ret = pack(...)
			if coroutine.status(this) == "suspended" then
				-- If we are suspended, then f_co has yielded control after calling f.
				-- Use the caller of this callback to resume computation until the next yield.
				coroutine.resume(this)
			end
		end, ...)
		if f_status == "running" then
			-- If we are here, then `f` must not have called the callback yet, so it will do so asynchronously.
			-- Yield control and wait for the callback to resume it.
			coroutine.yield()
		end
		return unpack(f_ret, 1, f_ret.n)
	end

	return f_co
end

--- Executes a coroutine function in a protected mode.
---
--- This is also a coroutine function.
---
--- copcall is a coroutine alternative to pcall. pcall is not suitable for coroutines, because yields can’t cross a
--- pcall. copcall goes around that restriction by using coroutine.resume.
---
---@async
---@param f_co function A coroutine function to execute.
---@return boolean success Whether the coroutine function executed successfully.
---@return ... The results of the coroutine function.
M.copcall = function(f_co, ...)
	local thread = coroutine.create(f_co)
	local results = pack(coroutine.resume(thread, ...))
	while true do
		if not results[1] then
			return false, results[2]
		end

		if coroutine.status(thread) == "dead" then
			return true, unpack(results, 2, results.n)
		end

		local args = pack(coroutine.yield())
		results = pack(coroutine.resume(thread, unpack(args, 1, args.n)))
	end
end

return M
