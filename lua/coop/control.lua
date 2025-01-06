--- Various utilities for async control flow.
local M = {}

local task = require("coop.task")
local Future = require("coop.future").Future

---@alias Awaitable Coop.Future|Coop.Task

--- Runs tasks in the sequence concurrently.
---
--- If all tasks are completed successfully, the result is an aggregate list of returned
--- values. The order of result values corresponds to the order of tasks.
---
--- The first raised exception is immediately propagated to the task that awaits on gather().
--- Active tasks in the sequence won’t be cancelled and will continue to run.
---
--- Cancelling the gather will cancel all tasks in the sequence.
---
---@async
---@param tasks Coop.Task[] the list of tasks.
---@return any ... results
M.gather = function(tasks)
	local task_count = #tasks
	if task_count == 0 then
		return {}
	end

	local replicate = require("coop.table-utils").replicate
	local results = replicate(task_count, nil)
	local future = Future.new()
	local done_count = 0

	for i, aw in ipairs(tasks) do
		aw:await(function(success, result, ...)
			tasks[i] = nil

			if success then
				results[i] = { result, ... }
			else
				future:error(result)
				return
			end

			done_count = done_count + 1
			if done_count == task_count then
				future:complete(results)
			end
		end)
	end

	local success, result = future:pawait()
	if success then
		return results
	else
		if result == "cancelled" and task.running():is_cancelled() then
			for _, t in ipairs(tasks) do
				if t ~= nil then
					t:cancel()
				end
			end
		end
		error(result, 0)
	end
end

-- `shield` can’t be implemented with `copcall`, because if a cancellation error
-- happens withing `copcall`, the error still finishes the wrapped function.
-- The only solution is to wrap the task function in a new task, so that
-- cancellation requests don’t reach the wrapped function.

--- Protects a task function from being cancelled.
---
--- The task function is executed in a new task.
---
--- If no cancellation is taking place, `shield(tf, ...)` is equivalent to `tf(...)`.
---
--- If the task wrapping `shield` is cancelled, the task function is allowed to complete.
--- Afterwards `shield` throws the cancellation error.
---
--- If it is desired to completely ignore cancellation, `shield` should be combined with `copcall`.
---
---@async
---@param tf async function The task function to protect.
---@param ... ... The arguments to pass to the task function.
---@return any ... The results of the task function.
M.shield = function(tf, ...)
	local spawn = require("coop.task-utils").spawn
	local pack = require("coop.table-utils").pack

	local this = task.running()
	if this == nil then
		error("shield can only be used in a task.")
	end

	local cancelled = false
	local cancel_msg = ""
	local t = spawn(tf, ...)
	local results = pack()
	while true do
		results = pack(t:pawait())

		if results[1] then
			break
		end

		if this:is_cancelled() then
			this:unset_cancelled()
			cancelled = true
			cancel_msg = results[2]
		else
			break
		end
	end

	if cancelled then
		this.cancelled = true
		error(cancel_msg, 0)
	elseif results[1] then
		return unpack(results, 2, results.n)
	else
		error(results[2], 0)
	end
end

--- Creates a task function that times out after the given duration.
---
--- If no timeout is taking place, `timeout(duration, tf, ...)` is equivalent to `tf(...)`.
---
--- If a timeout happens, `timeout` throws `error("timeout")`.
---
--- If the returned task function is cancelled, so is the wrapped task function.
---
---@async
---@param duration integer The duration in milliseconds.
---@param tf async function The task function to run.
---@param ... ... The arguments to pass to the task function.
---@return ... ... The results of the task function.
M.timeout = function(duration, tf, ...)
	local spawn = require("coop.task-utils").spawn
	local sleep = require("coop.uv-utils").sleep
	local pack = require("coop.table-utils").pack

	local t = spawn(tf, ...)
	local timed_out = false

	-- Start the watchdog.
	spawn(function()
		sleep(duration)
		if t:status() ~= "dead" then
			timed_out = true
			t:cancel()
		end
	end)

	local results = pack(t:pawait())

	if t:status() == "dead" then
		if results[1] then
			return unpack(results, 2, results.n)
		elseif timed_out == true then
			error("timeout", 0)
		else
			error(results[2], 0)
		end
	else
		assert(
			task.running():is_cancelled(),
			"timeout encountered an invalid state. Report to Coop.nvim maintainer."
		)
		t:cancel()
		error(results[2], 0)
	end
end

--- Waits for any of the given awaitables to complete.
---
---@async
---@param aws Awaitable[]
---@return Awaitable done the first awaitable that completed
---@return Awaitable[] done the remaining awaitables
M.await_any = function(aws)
	if #aws == 0 then
		error("The list of awaitables is empty.", 0)
	end
	local future = Future.new()

	for i, aw in ipairs(aws) do
		aw:await(function()
			if future.done then
				-- There’s already an awaitable that has completed.
				return
			end
			future:complete(i, aw)
		end)
	end

	local aw_pos, aw = future()
	table.remove(aws, aw_pos)
	return aw, aws
end

--- Awaits all awaitables in the list.
---
---@async
---@param aws Awaitable[]
---@return table results The results of the awaitables.
M.await_all = function(aws)
	local done_count = 0
	local this = task.running()
	if this == nil then
		error("await_all can only be used in a task.")
	end
	local results = {}
	for _ = 1, #aws do
		table.insert(results, nil)
	end

	for i, f in ipairs(aws) do
		f:await(function(...)
			results[i] = { ... }
			done_count = done_count + 1
			if done_count == #aws and task.status(this) == "suspended" then
				task.resume(this)
			end
		end)
	end

	if done_count < #aws then
		task.yield()
	end
	return results
end

--- Asynchronously iterates over the given awaitables and waits for each to complete.
---
---@async
---@param aws Awaitable[]
M.as_completed = function(aws)
	return function()
		if #aws == 0 then
			return
		end
		local done
		done, aws = M.await_any(aws)
		return done
	end
end

return M
