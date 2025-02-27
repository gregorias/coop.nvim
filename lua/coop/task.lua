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
---@class Coop.Task
---@field thread thread the coroutine thread
---@field future Coop.Future the future for the coroutine
---
---@field status fun(self: Coop.Task): string returns the task’s status
---@field resume fun(self: Coop.Task, ...): boolean, ... resumes the task
---
---@field cancel fun(self: Coop.Task): boolean, ... cancels the task
---@field cancelled boolean true if the user has requested cancellation
---@field is_cancelled fun(self: Coop.Task): boolean returns true if the task is cancelled
---@field unset_cancelled fun(self: Coop.Task) unsets the cancelled flag
---
---@field await function awaits the task
---@field pawait async fun(self: Coop.Task): boolean, ... awaits the task and returns errors

local running_task = nil

--- Creates a new task.
---
---@param tf function the task function
---@return Coop.Task
M.create = function(tf)
	local future_m = require("coop.future")
	local future = future_m.Future.new()

	local task = {
		thread = coroutine.create(tf),
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
			pawait = function(self)
				return self.future:pawait()
			end,

			is_cancelled = function(self)
				return self.cancelled
			end,
			unset_cancelled = function(self)
				self.cancelled = false
			end,
		},
		__call = function(self, ...)
			return self.future(...)
		end,
	})
end

--- Resumes a task with the specified arguments.
---
---@param task Coop.Task the task to resume
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
		task.future:error(results[2])
	elseif coroutine.status(task.thread) == "dead" then
		task.future:complete(unpack(results, 2, results.n))
	end

	return unpack(results, 1, results.n)
end

--- Cancels a task.
---
--- The cancelled task will throw `error("cancelled")` in its yield.
--- If you intercept cancellation, you need to unset the `cancelled` flag with with
--- Task:unset_cancelled.
---
--- `cancel` resumes the task. It’s like sending a cancellation signal that the task needs to
--- handle.
---
---@param task Coop.Task the task to cancel
---@return boolean success
---@return any ... results
M.cancel = function(task)
	local task_status = M.status(task)

	if task_status == "dead" then
		-- The task is already dead (finished). Don’t do anything.
		return false, "dead"
	end

	if task_status == "running" or task_status == "normal" then
		error("You cannot cancel the currently running task.", 0)
	end

	assert(task_status == "suspended")

	task.cancelled = true
	return task:resume()
end

--- Returns the currently running task or nil.
---
---@return Coop.Task?
M.running = function()
	return running_task
end

--- Yields the current task.
---
--- If inside a cancelled task, it throws an error message "cancelled".
---
---@async
---@param ... ... the arguments
---@return any ... the arguments passed to task.resume
M.yield = function(...)
	local args = pack(M.pyield(...))

	if args[1] == true then
		return unpack(args, 2, args.n)
	else
		error(args[2], 0)
	end
end

--- Yields the current task.
---
--- `p` stands for "protected" like in `pcall`.
---
---@async
---@param ... ... the arguments
---@return boolean success true iff the task was not cancelled
---@return any ... the arguments passed to task.resume or "cancelled"
M.pyield = function(...)
	local this = M.running()

	if not this then
		error("Called pyield outside of a running task. Make sure that you use yield in tasks.", 0)
	end

	if this:is_cancelled() then
		error(
			"Called pyield inside a cancelled task."
				.. " If you want to intercept cancellation,"
				.. " you need to clear the cancellation flag with unset_cancelled.",
			0
		)
	end

	local args = pack(coroutine.yield(...))

	this = M.running()

	if not this then
		error(
			"coroutine.yield returned without a running task. Make sure that you use task.resume to resume tasks.",
			0
		)
	end

	if this.cancelled then
		return false, "cancelled"
	end

	return true, unpack(args, 1, args.n)
end

--- Returns the status of a task’s thread.
---
---@param task Coop.Task the task
---@return string "running" | "suspended" | "normal" | "dead"
M.status = function(task)
	return coroutine.status(task.thread)
end

return M
