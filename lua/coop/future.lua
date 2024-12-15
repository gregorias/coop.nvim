--- This module provides a future implementation.
local M = {}

local pack = require("coop.table-utils").pack
local unpack_packed = require("coop.table-utils").unpack_packed

--- A future is a synchronization mechanism that allows waiting for a task to return.
---
--- Futures turn spawned task functions back into task functions as they implement the call operator.
---
---@class Future
---@field done boolean Whether the future is done.
---@field results table The results of the coroutine in pcall/coroutine.resume + pack format.
---@field queue table The queue of callbacks to be called once the future is done.
---
---@field complete function A function that marks the future as done with the specified results and calls the callbacks
---                         in the waiting queue.
---@field error function A function that marks the future as finished with an error and calls the callbacks in the
---                      waiting queue.
---
---@field await function Waits for the future to be done.
---@field pawait async fun(Future): boolean, ... Waits for the future to be done.
M.Future = {}

--- Creates a new future.
---
---@return Future future the new future.
M.Future.new = function()
	local future = { done = false, queue = {} }
	local meta_future = {
		__index = M.Future,
		__call = M.Future.await,
	}
	return setmetatable(future, meta_future)
end

--- Marks the future as done with the specified results and calls callbacks in the waiting queue.
---
---@param ... any The results of the coroutine function.
M.Future.complete = function(self, ...)
	if self.done then
		error("Tried to complete an already done future.")
	end

	self.results = pack(true, ...)
	self.done = true
	for _, cb in ipairs(self.queue) do
		cb(unpack(self.results, 1, self.results.n))
	end
	self.queue = {}
end

--- Marks the future as done with an error and calls callbacks in the waiting queue.
---
---@param self Future the future
---@param err string the error message
M.Future.error = function(self, err)
	if self.done then
		error("Tried to set an error on an already done future.")
	end

	self.results = { [1] = false, [2] = err, n = 2 }
	self.done = true
	for _, cb in ipairs(self.queue) do
		cb(unpack(self.results, 1, self.results.n))
	end
	self.queue = {}
end

--- Waits for the future to be done.
---
--- This function can be called in three different ways:
---
--- - `await()`: This is a task function that yields until the future is done.
--- - `await(cb)`: This calls the callback with the results of the task function when the future is done.
--- - `await(timeout, interval)`: This function uses busy waiting to wait for the future to be done.
M.Future.await = function(self, cb_or_timeout, interval)
	if cb_or_timeout == nil then
		return self:await_tf()
	elseif type(cb_or_timeout) == "function" then
		return self:await_cb(cb_or_timeout)
	elseif type(cb_or_timeout) == "number" then
		return self:wait(cb_or_timeout, interval)
	else
		error("Called await with invalid arguments.")
	end
end

--- Waits for the future to be done.
---
---@param self Future the future
---@return boolean success whether the future was successful and the pawait was not cancelled.
---@return any ... the results of the task function or an error message.
M.Future.pawait = function(self)
	return self:pawait_tf()
end

--- Asynchronously waits for the future to be done.
---
--- This is a task function that yields until the future is done.
---
--- Rethrows the error if the future ended with an error or the await was cancelled.
---
---@async
---@param self Future the future
---@return any ... the results of the task function
M.Future.await_tf = function(self)
	local results = pack(self:pawait_tf())
	if results[1] then
		return unpack(results, 2, results.n)
	else
		error(results[2], 0)
	end
end

--- Asynchronously waits for the future to be done.
---
--- This calls the callback with the results of the coroutine function when the future is done.
---
---@param self Future the future
---@param cb function The callback to call with the results of the coroutine.
M.Future.await_cb = function(self, cb)
	if self.done then
		cb(unpack(self.results, 1, self.results.n))
		return
	else
		table.insert(self.queue, cb)
		return
	end
end

--- Synchronously waits for the future to be done.
---
--- This function uses busy waiting to wait for the future to be done.
---
--- This function throws an error if the future ended with an error.
---
---@param timeout number The timeout in milliseconds.
---@param interval number The interval in milliseconds between checks.
---@return any ... The results of the coroutine function if done.
M.Future.wait = function(self, timeout, interval)
	vim.wait(timeout, function()
		return self.done
	end, interval)
	if self.done then
		if self.results[1] then
			return unpack(self.results, 2, self.results.n)
		else
			error(self.results[2], 0)
		end
	else
		return
	end
end

--- Asynchronously waits for the future to be done.
---
--- This is a task function that yields until the future is done.
---
---@async
---@param self Future the future
---@return boolean success whether the future was successful and the await was not cancelled.
---@return any ... the results of the task function or an error message.
M.Future.pawait_tf = function(self)
	local running, yield_msg = true, ""
	if not self.done then
		local task = require("coop.task")
		local this = task.running()
		if this == nil then
			error("Future.pawait can only be used in a task.", 2)
		end

		table.insert(self.queue, function()
			if not running then
				-- This await was cancelled during yield. There’s nothing to resume.
				return
			end

			task.resume(this)
		end)

		running, yield_msg = task.pyield()
	end

	-- The await was cancelled.
	if not running then
		return false, yield_msg
	end

	return unpack_packed(self.results)
end

return M
