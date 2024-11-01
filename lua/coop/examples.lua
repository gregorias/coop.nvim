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
	local results = {}
	for _, value in ipairs(values) do
		table.insert(
			futures,
			coop.spawn(function()
				uv.sleep(value)
				table.insert(results, value)
			end)
		)
	end
	coop.await_all(futures)
	return results
end

return M
