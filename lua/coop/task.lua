--- This module provides a task implementation.
local M = {}

local pack = require("coop.table-utils").pack

--- A task is an extension of Lua coroutine.
---
--- A task enhances Lua coroutine with:
---
--- - A future that can be awaited.
--- - The ability to capture errors.
--- - The ability to cancel and handle cancellation.
---
---@class Task
---@field thread thread the coroutine thread
---@field future Future the future for the coroutine
---@field cancelled boolean true if the user has requested cancellation
---
---@field cancel fun(Task) cancels the task
---@field resume fun(Task, ...) resumes the task
---@field status fun(Task): string returns the task’s status
---
---@field await function awaits the task

local running_task = nil

--- Creates a new task.
---
---@param tf function the task function
---@return Task
M.create = function(tf)
	local future_m = require("coop.future")
	local future = future_m.Future.new()

	local task = {
		thread = coroutine.create(function(...)
			future:complete(tf(...))
		end),
		future = future,
		cancelled = false,
	}

	return setmetatable(task, {
		__index = {
			cancel = M.cancel,
			resume = M.resume,
			status = M.status,

			await = function(self, ...)
				return self.future:await(...)
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
---@return any ... results
M.resume = function(task, ...)
	if task:status() ~= "suspended" then
		error("Tried to resume a task that is not suspended but " .. task:status() .. ".", 0)
	end

	local previous_task = M.running()
	running_task = task
	local results = pack(coroutine.resume(task.thread, ...))
	running_task = previous_task

	if not results[1] then
		task.future:set_error(results[2])
	end

	return unpack(results, 1, results.n)
end

--- Cancels a task.
---
--- The cancelled task will throw `error("cancelled")` in its yield.
---
---@param task Task the task to cancel
M.cancel = function(task)
	local task_status = M.status(task)

	if task_status == "dead" then
		-- The task is already dead (finished). Don’t do anything.
		return
	end

	if task_status == "running" or task_status == "normal" then
		error("You cannot cancel the currently running task.", 0)
	end

	assert(task_status == "suspended")

	task.cancelled = true
	task:resume()
end

--- Returns the currently running task or nil.
---
---@return Task?
M.running = function()
	return running_task
end

--- Yields the current task.
---
--- This is a coroutine function.
---
--- If inside a cancelled task, it throws an error message "cancelled".
---
---@async
---@return any ... the arguments passed to task.resume
M.yield = function()
	local args = pack(coroutine.yield())

	local this = M.running()

	if not this then
		error("coroutine.yield returned without a running task. Make sure that you use task.resume to resume tasks.", 0)
	end

	if this.cancelled then
		-- Clear the cancelled flag, so that the user can ignore it.
		this.cancelled = false
		error("cancelled", 0)
	end

	return unpack(args, 1, args.n)
end

--- Returns the status of a task’s thread.
---
---@param task Task the task
---@return string "running" | "suspended" | "normal" | "dead"
M.status = function(task)
	return coroutine.status(task.thread)
end

return M
