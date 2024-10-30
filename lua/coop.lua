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
---@param  f function The function to convert. The callback needs to be its first argument.
---@return function co A coroutine function. Accepts the same arguments as f without the callback.
---                    Returns what f has passed to the callback.
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

--- A future is a synchronization mechanism that allows waiting for a coroutine to return.
---
--- Futures turn spawn coroutine functions back into coroutine functions as they implement the call operator.
---
---@class Future
---@field done boolean Whether the future is done.
---@field results table The results of the coroutine function.
---@field queue table The queue of callbacks to be called once the future is done.
---@field complete function A function that marks the future as done with the specified results and resumes coroutines
---                         in the waiting queue.
---@field wait function A function that waits for the future to be done.
M.Future = {}

--- Creates a new future.
M.Future.new = function()
	local future = { done = false, queue = {} }
	local meta_future = {
		__index = M.Future,
		__call = M.Future.wait,
	}
	return setmetatable(future, meta_future)
end

--- Marks the future as done with the specified results and resumes coroutines in the waiting queue.
---
---@param ... any The results of the coroutine function.
M.Future.complete = function(self, ...)
	if self.done then
		error("Tried to complete an already done future.")
	end

	self.results = pack(...)
	self.done = true
	for _, cb in ipairs(self.queue) do
		cb(...)
	end
	self.queue = {}
end

--- Waits for the future to be done.
---
--- If no callback is provided, this is a coroutine function that yields until the future is done.
---
--- If a callback is provided, this calls the callback with the results of the coroutine function when the future is
--- done.
---
---@param cb? function The callback to call with the results of the coroutine function.
---@return any results The results of the coroutine function if no callback is provided. Otherwise, nothing.
M.Future.wait = function(self, cb)
	if cb then
		if self.done then
			cb(unpack(self.results))
			return
		else
			table.insert(self.queue, cb)
			return
		end
	end

	if self.done then
		return unpack(self.results)
	else
		local this = coroutine.running()
		table.insert(self.queue, function(...)
			coroutine.resume(this, ...)
		end)
		return coroutine.yield()
	end
end

--- Spawns a coroutine function in a thread.
---
--- The returned future can turn the coroutine back into a coroutine function.
--- spawn(f_co, ...)() is semantically the same as f_co(...)
---
---@param f_co function The coroutine function to spawn.
---@return Future future The future for the coroutine.
M.spawn = function(f_co, ...)
	local future = M.Future.new()
	local args = { ... }
	coroutine.resume(coroutine.create(function()
		future:complete(f_co(unpack(args)))
	end))
	return future
end

--- Spawns and forgets a coroutine function.
---
---@tparam function f_co The coroutine function to fire and forget.
M.fire_and_forget = function(...)
	M.spawn(...)
end

--- Awaits all futures in a list.
---
--- This is a coroutine function.
---
---@param futures table A list of futures to await.
---@return table results The results of the futures.
M.await_all = function(futures)
	local done_count = 0
	local this = coroutine.running()
	local results = {}
	for _ = 1, #futures do
		table.insert(results, nil)
	end

	for i, f in ipairs(futures) do
		f:wait(function(...)
			results[i] = { ... }
			done_count = done_count + 1
			if done_count == #futures and coroutine.status(this) == "suspended" then
				coroutine.resume(this)
			end
		end)
	end

	if done_count < #futures then
		coroutine.yield()
	end
	return results
end

return M
