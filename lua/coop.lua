--- The main module containing for Coop’s utility functions.
local M = {}

local pack = function(...)
	-- selene: allow(mixed_table)
	return { n = select("#", ...), ... }
end

--- Converts a callback-based function to a coroutine function.
---
--- If the callback is called asynchronously, then the coroutine function yield exactly once and is resumed by whoever
--- calls the callback. If the callback is called synchronously, then the coroutine function returns immediately.
---
---@tparam  function f The function to convert. The callback needs to be its first argument.
---@treturn function A coroutine function. Accepts the same arguments as f without the callback.
---                  Returns what f has passed to the callback.
M.cb_to_co = function(f)
	local f_co = function(...)
		local this = coroutine.running()
		assert(this ~= nil, "The result of cb_to_co must be called within a coroutine.")

		local f_status = "running"
		local f_ret = pack()
		-- f needs to have the callback as its first argument, because varargs passing doesn’t work otherwise.
		f(function(...)
			f_status = "done"
			f_ret = pack(...)
			if coroutine.status(this) == "suspended" then
				-- If we are suspended, then f_co has yielded control after calling f.
				-- Use the caller of this callback to resume computation until the next yield.
				local cb_ret = pack(coroutine.resume(this))
				if not cb_ret[1] then
					error(cb_ret[2])
				end
				return unpack(cb_ret, 2, cb_ret.n)
			end
		end, ...)
		if f_status == "running" then
			-- If we are here, then `f` must not have called the callback yet, so it will do so asynchronously.
			-- Yield control and wait for the callback to resume it.
			coroutine.yield()
		end
		return unpack(f_ret, 1, f_ret.n)
	end

	return f_co
end

--- Spawns a coroutine function in a thread.
---
---@tparam function f_co The coroutine function to spawn.
---@treturn any The result of the coroutine function until the first yield.
M.spawn = function(f_co, ...)
	local result = pack(coroutine.resume(coroutine.create(f_co), ...))
	return unpack(result, 2, result.n)
end

--- Spawns and forgets a coroutine function.
---
---@tparam function f_co The coroutine function to fire and forget.
M.fire_and_forget = function(...)
	M.spawn(...)
end

--- Notification is a synchronization mechanism that unlocks threads once a work has been completed.
M.Notification = {}

local meta_notification = {
	__index = M.Notification,
}

M.Notification.new = function()
	return setmetatable({ done = false, queue = {} }, meta_notification)
end

--- Notifies all waiting threads.
M.Notification.notify = function(self)
	if not self.done then
		self.done = true
		for _, co in ipairs(self.queue) do
			coroutine.resume(co)
		end
	end
end

--- Waits for the notification to be triggered.
---
--- This is a coroutine function that yields until the notification is triggered.
M.Notification.wait = function(self)
	if not self.done then
		table.insert(self.queue, coroutine.running())
		coroutine.yield()
	end
end

return M
