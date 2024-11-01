--- This module provides a task implementation.
local M = {}

--- A task is a thin wrapper on top of a coroutine.
---
--- A task enhances a coroutine with a future that can be awaited and the ability to capture errors.
---
---@class Task
---@field thread thread the coroutine thread
---@field future Future the future for the coroutine

local running_task = nil

---@return Task
M.create = function(co)
	local future_m = require("coop.future")
	local future = future_m.Future.new()
	return {
		thread = coroutine.create(function(...)
			future:complete(co(...))
		end),
		future = future,
	}
end

--- Resumes a task with the specified arguments.
---
---@param task Task the task to resume
---@param ... ... the arguments
---@return boolean success
---@return ...
M.resume = function(task, ...)
	local previous_task = M.running()
	running_task = task
	local results = { coroutine.resume(task.thread, ...) }
	running_task = previous_task

	if not results[1] then
		task.future:set_error(results[2])
	end

	return unpack(results)
end

--- Returns the currently running task or nil.
---
---@return Task?
M.running = function()
	return running_task
end

M.yield = coroutine.yield

--- Returns the status of a task’s thread.
---
---@param task Task the task
---@return string "running" | "suspended" | "normal" | "dead"
M.status = function(task)
	return coroutine.status(task.thread)
end

return M
