--- Various utilities for async control flow.
local M = {}

local task = require("coop.task")
local Future = require("coop.future").Future

---@alias Awaitable Future|Task

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
