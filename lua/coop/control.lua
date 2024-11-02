--- Various utilities for async control flow.
local M = {}
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
