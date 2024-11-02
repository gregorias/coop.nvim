--- The main module containing for Coop’s utility functions.
local M = {}

local task = require("coop.task")

M.Future = require("coop.future").Future
M.cb_to_tf = require("coop.task-utils").cb_to_tf
M.spawn = require("coop.task-utils").spawn

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
		f:await(function(...)
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
