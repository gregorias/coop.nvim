--- The main module containing for Coop’s utility functions.
local M = {}

local pack = require("coop.table-utils").pack
local task = require("coop.task")

M.Future = require("coop.future").Future

--- Converts a callback-based function to a coroutine function.
---
--- If the callback is called asynchronously, then the coroutine function yield exactly once and is resumed by whoever
--- calls the callback. If the callback is called synchronously, then the coroutine function returns immediately.
---
---@param  f function The function to convert. The callback needs to be its first argument.
---@return function co A coroutine function. Accepts the same arguments as f without the callback.
---                    Returns what f has passed to the callback.
M.cb_to_co = function(f)
	local f_co = function(...)
		local this = task.running()
		assert(this ~= nil, "The result of cb_to_co must be called within a coroutine.")

		local f_status = "running"
		local f_ret = pack()
		-- f needs to have the callback as its first argument, because varargs passing doesn’t work otherwise.
		f(function(...)
			f_status = "done"
			f_ret = pack(...)
			if task.status(this) == "suspended" then
				-- If we are suspended, then f_co has yielded control after calling f.
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

	return f_co
end

--- Spawns a coroutine function in a thread.
---
--- The returned future can turn the coroutine back into a coroutine function.
--- spawn(f_co, ...)() is semantically the same as f_co(...)
---
---@param f_co function The coroutine function to spawn.
---@return Task task the spawned task
M.spawn = function(f_co, ...)
	local spawned_task = task.create(f_co)
	task.resume(spawned_task, ...)
	return spawned_task
end

--- Spawns and forgets a coroutine function.
---
---@tparam function f_co The coroutine function to fire and forget.
M.fire_and_forget = function(...)
	M.spawn(...)
end

--- Awaits all futures in a list.
---
--- This is a coroutine function.
---
---@param futures table A list of futures to await.
---@return table results The results of the futures.
M.await_all = function(futures)
	local done_count = 0
	local this = task.running()
	if this == nil then
		error("await_all can only be used in a task.")
	end
	local results = {}
	for _ = 1, #futures do
		table.insert(results, nil)
	end

	for i, f in ipairs(futures) do
		f:await_cb(function(...)
			results[i] = { ... }
			done_count = done_count + 1
			if done_count == #futures and task.status(this) == "suspended" then
				task.resume(this)
			end
		end)
	end

	if done_count < #futures then
		task.yield()
	end
	return results
end

return M
