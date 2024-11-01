--- This module provides a task implementation.
local M = {}

--- A task is a thin wrapper on top of a coroutine.
---
--- A task enhances a coroutine with a future that can be awaited and the ability to capture errors.
---
--- For convenience, a task exposes its future’s methods.
---
---@class Task
---@field thread thread the coroutine thread
---@field future Future the future for the coroutine
---@field cancelled boolean whether the task has been cancelled
---@field await function awaits the task
---@field await_cb function awaits the task
---@field wait function synchronously waits for the task

local running_task = nil

---@return Task
M.create = function(co)
	local future_m = require("coop.future")
	local future = future_m.Future.new()

	local task = {
		thread = coroutine.create(function(...)
			future:complete(co(...))
		end),
		future = future,
		cancelled = false,
	}

	return setmetatable(task, {
		__index = {
			await = function(self, ...)
				return self.future:await(...)
			end,
			await_cb = function(self, ...)
				return self.future:await_cb(...)
			end,
			wait = function(self, ...)
				return self.future:wait(...)
			end,
		},
		__call = function(self, ...)
			return self.future(...)
		end,
	})
end

--- Resumes a task with the specified arguments.
---
---@param task Task the task to resume
---@param ... ... the arguments
---@return boolean success
---@return ...
M.resume = function(task, ...)
	if task.cancelled then
		return false, "The task was cancelled."
	end

	local previous_task = M.running()
	running_task = task
	local results = { coroutine.resume(task.thread, ...) }
	running_task = previous_task

	if not results[1] then
		task.future:set_error(results[2])
	end

	return unpack(results)
end

--- Cancels a task.
M.cancel = function(task)
	local task_status = M.status(task)

	if task_status == "dead" then
		-- The task is already dead (finished). Don’t do anything.
		return
	end

	if task_status == "running" or task_status == "normal" then
		error("You cannot cancel the currently running task.", 0)
	end

	task.cancelled = true
	task.future:set_error("Task was cancelled.")
end

--- Returns the currently running task or nil.
---
---@return Task?
M.running = function()
	return running_task
end

--- Yields the current task.
M.yield = coroutine.yield

--- Returns the status of a task’s thread.
---
---@param task Task the task
---@return string "running" | "suspended" | "normal" | "dead"
M.status = function(task)
	if task.cancelled then
		return "dead"
	end
	return coroutine.status(task.thread)
end

return M
