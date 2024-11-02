--- This module provides a future implementation.
local M = {}

--- A future is a synchronization mechanism that allows waiting for a task to return.
---
--- Futures turn spawned task functions back into task functions as they implement the call operator.
---
---@class Future
---@field done boolean Whether the future is done.
---@field results table The results of the coroutine in pcall/coroutine.resume format.
---@field queue table The queue of callbacks to be called once the future is done.
---
---@field complete function A function that marks the future as done with the specified results and calls the callbacks
---                         in the waiting queue.
---@field set_error function A function that marks the future as finished with an error and calls the callbacks
---                          in the waiting queue.
---
---@field await function Waits for the future to be done.
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

	self.results = { ... }
	table.insert(self.results, 1, true)
	self.done = true
	for _, cb in ipairs(self.queue) do
		cb(unpack(self.results))
	end
	self.queue = {}
end

--- Marks the future as done with an error and calls callbacks in the waiting queue.
---
---@param self Future the future
---@param err string the error message
M.Future.set_error = function(self, err)
	if self.done then
		error("Tried to set an error on an already done future.")
	end

	self.results = { false, err }
	self.done = true
	for _, cb in ipairs(self.queue) do
		cb(unpack(self.results))
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

--- Asynchronously waits for the future to be done.
---
--- This is a task function that yields until the future is done.
---
---@async
---@param self Future the future
---@return any results the results of the task function
M.Future.await_tf = function(self)
	if self.done then
		return unpack(self.results)
	else
		local task = require("coop.task")
		local this = task.running()
		if this == nil then
			error("Future.await can only be used in a task.")
		end

		table.insert(self.queue, function(...)
			task.resume(this, ...)
		end)

		local results = { task.yield() }
		if results[1] then
			return unpack(results, 2, #results)
		else
			error(results[2], 0)
		end
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
		cb(unpack(self.results))
		return
	else
		table.insert(self.queue, cb)
		return
	end
end

--- Synchronously wait for the future to be done.
---
--- This function uses busy waiting to wait for the future to be done.
---
--- This function throws an error if the future ended with an error.
---
---@param timeout number The timeout in milliseconds.
---@param interval number The interval in milliseconds between checks.
---@return any results The results of the coroutine function if done.
M.Future.wait = function(self, timeout, interval)
	vim.wait(timeout, function()
		return self.done
	end, interval)
	if self.done then
		if self.results[1] then
			return unpack(self.results, 2, #self.results)
		else
			error(self.results[2])
		end
	else
		return
	end
end

return M
