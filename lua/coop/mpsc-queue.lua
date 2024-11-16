--- This module provides a multiple-producer single-consumer queue.
local M = {}

--- A multiple-producer single-consumer queue.
---
--- The queue uses a buffer and its push is always non-blocking.
--- The pop operation is blocking iff the queue is empty.
---
---@class MpscQueue
---@field waiting Task
---@field head? MpscQueueNode
---@field tail? MpscQueueNode
---@field push fun(self: MpscQueue, value: any)
---@field pop async fun(self: MpscQueue): any
---@field empty fun(self: MpscQueue): boolean

---@class MpscQueueNode
---@field value any
---@field next? MpscQueueNode

M.MpscQueue = {}

--- Creates a new multiple-producer single-consumer queue.
---
---@return MpscQueue
M.MpscQueue.new = function()
	local mpsc_queue = { waiting = nil, head = nil, tail = nil }
	return setmetatable(mpsc_queue, { __index = M.MpscQueue })
end

--- Pushes a value to the queue.
---
---@param self MpscQueue
---@param value any
M.MpscQueue.push = function(self, value)
	if self.waiting then
		local waiting = self.waiting
		waiting:resume(value)
		return
	end

	if self.head == nil then
		self.head = { value = value, next = nil }
		self.tail = self.head
	else
		self.tail.next = { value = value, next = nil }
		self.tail = self.tail.next
	end
end

--- Pops a value from the queue.
---
--- This method yields iff the queue is empty.
---
---@async
---@param self MpscQueue
---@return any value
M.MpscQueue.pop = function(self)
	if self.head == nil then
		if self.waiting ~= nil then
			error("Some other task is already waiting for a value.")
		end

		local task = require("coop.task")
		local this = task.running()
		if this == nil then
			error("Pop must be called within a task.")
		end

		self.waiting = this
		local success, value = task.pyield()
		self.waiting = nil
		if success then
			return value
		else
			error(value, 0)
		end
	end

	local value = self.head.value
	self.head = self.head.next
	return value
end

--- Checks if the queue is empty.
---
---@param self MpscQueue
---@return boolean
M.MpscQueue.empty = function(self)
	return self.head == nil
end

return M
