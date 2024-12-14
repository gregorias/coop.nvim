--- Utilities related to tasks.
local M = {}

local pack = require("coop.table-utils").pack
local task = require("coop.task")

---@class CbToTfOpts
---@field on_cancel? fun(table, table) The function to call when the task is cancelled.
---                                    This can be used to stop allocation of resources.
---                                    This function receives packed tables with the original call’s arguments and
---                                    the immediately returned values (useful if the function returns a cancellable
---                                    handle).
---@field cleanup? fun(...) The function to call when the task has been cancelled but the callback gets called.
---                         This can be used to clean up allocated resources.
---                         This function receives the callback arguments.

local normalize_cp_to_tf_opts = function(opts)
	opts = opts or {}
	opts.on_cancel = opts.on_cancel or function(...) end
	opts.cleanup = opts.cleanup or function(...) end
	return opts
end

--- Converts a callback-based function to a task function.
---
--- If the callback is called asynchronously, then the task function yields exactly once and is resumed by whoever
--- calls the callback. If the callback is called synchronously, then the task function returns immediately.
---
--- This function is more involved than `cb_to_co` to handle the case of task cancellation. If the task is cancelled,
--- the user needs options to handle the eventual cleanup.
---
---@param f function The function to convert. The callback needs to be its first argument.
---@param opts? CbToTfOpts The clean up options.
---@return async function tf A task function. Accepts the same arguments as f without the callback.
---                          Returns what f has passed to the callback.
M.cb_to_tf = function(f, opts)
	opts = normalize_cp_to_tf_opts(opts)

	local f_tf = function(...)
		local this = task.running()
		assert(this ~= nil, "The result of cb_to_tf must be called within a task.")

		local f_status = "running"
		local f_cb_ret = pack()
		-- f needs to have the callback as its first argument, because varargs passing doesn’t work otherwise.
		local f_ret = pack(f(function(...)
			if f_status == "cancelled" then
				-- The task has been cancelled before this callback. Just run the cleanup function to cleanup
				-- any allocated resources.
				opts.cleanup(...)
				return
			end

			f_status = "done"
			f_cb_ret = pack(...)
			if task.status(this) == "suspended" then
				-- If we are suspended, then f_tf has yielded control after calling f.
				-- Use the caller of this callback to resume computation until the next yield.
				task.resume(this)
			end
		end, ...))
		if f_status == "running" then
			-- If we are here, then `f` must not have called the callback yet, so it will do so asynchronously.
			-- Yield control and wait for the callback to resume it.
			local running, err_msg = task.pyield()
			if not running then
				f_status = "cancelled"
				opts.on_cancel(pack(...), f_ret)
				error(err_msg, 0)
			end
		end

		return unpack(f_cb_ret, 1, f_cb_ret.n)
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

--- Transforms a coroutine function into a task function.
---
---@param f_co async function The coroutine function.
---@return async function tf The task function.
M.co_to_tf = function(f_co)
	local unpack_packed = require("coop.table-utils").unpack_packed

	return function(...)
		local thread = coroutine.create(f_co)
		local results = pack(coroutine.resume(thread, ...))
		while true do
			if not results[1] then
				error(results[2], 0)
			end

			if coroutine.status(thread) == "dead" then
				return unpack(results, 2, results.n)
			end

			-- The coroutine function has yielded, so we need to yield as well.
			local args = pack(task.yield(unpack(results, 2, results.n)))
			results = pack(coroutine.resume(thread, unpack_packed(args)))
		end
	end
end

return M
