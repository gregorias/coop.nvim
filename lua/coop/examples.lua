local M = {}
local coop = require("coop")
local uv = require("coop.uv")

--- Sorts a list of numbers by waiting for the time of each number.
---
--- This is a coroutine function.
---
--- This is a good example of true parallelism enabled by this framework (each timer is working in parallel) and
--- `await_all` for synchronization.
---
---@param values number[] the values to sort
---@return number[] sorted_values the sorted values
M.sort_with_time = function(values)
	local futures = {}
	local sorted_results = {}

	-- For each number, create a task that sleeps for that number of milliseconds.
	for _, value in ipairs(values) do
		local future = coop.spawn(function()
			uv.sleep(value)
			table.insert(sorted_results, value)
		end)
		table.insert(futures, future)
	end

	coop.await_all(futures)

	return sorted_results
end

return M
