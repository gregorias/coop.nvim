--- Utilities related to tasks.
local M = {}

local pack = require("coop.table-utils").pack
local task = require("coop.task")

--- Converts a callback-based function to a task function.
---
--- If the callback is called asynchronously, then the task function yields exactly once and is resumed by whoever
--- calls the callback. If the callback is called synchronously, then the task function returns immediately.
---
---@param  f function The function to convert. The callback needs to be its first argument.
---@return async function tf A task function. Accepts the same arguments as f without the callback.
---                          Returns what f has passed to the callback.
M.cb_to_tf = function(f)
	local f_tf = function(...)
		local this = task.running()
		assert(this ~= nil, "The result of cb_to_tf must be called within a task.")

		local f_status = "running"
		local f_ret = pack()
		-- f needs to have the callback as its first argument, because varargs passing doesn’t work otherwise.
		f(function(...)
			f_status = "done"
			f_ret = pack(...)
			if task.status(this) == "suspended" then
				-- If we are suspended, then f_tf has yielded control after calling f.
				-- Use the caller of this callback to resume computation until the next yield.
				task.resume(this)
			end
		end, ...)
		if f_status == "running" then
			-- If we are here, then `f` must not have called the callback yet, so it will do so asynchronously.
			-- Yield control and wait for the callback to resume it.
			task.yield()
		end
		return unpack(f_ret, 1, f_ret.n)
	end

	return f_tf
end

--- Spawns a task function in a thread.
---
--- The returned task can be turned back into a task function.
--- spawn(f_co, ...)() is semantically the same as f_co(...)
---
---@param f_co function The task function to spawn.
---@return Task task the spawned task
M.spawn = function(f_co, ...)
	local spawned_task = task.create(f_co)
	task.resume(spawned_task, ...)
	return spawned_task
end

return M
