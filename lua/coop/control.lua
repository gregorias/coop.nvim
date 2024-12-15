--- Various utilities for async control flow.
local M = {}

local task = require("coop.task")
local Future = require("coop.future").Future

---@alias Awaitable Future|Task

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
---@param tasks Task[] the list of tasks.
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
--- This is a task function.
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
