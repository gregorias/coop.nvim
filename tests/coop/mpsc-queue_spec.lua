--- Busted tests for coop.mpsc-queue.
local coop = require("coop")
local mpsc_queue = require("coop.mpsc-queue")

describe("coop.mpsc-queue", function()
	it("queues and dequeues multiple values", function()
		local q = mpsc_queue.MpscQueue.new()
		q:push(1)
		q:push(2)
		q:push(3)

		assert.are.same(1, q:pop())
		assert.are.same(2, q:pop())
		assert.are.same(3, q:pop())
	end)

	it("handles waiting by a single client", function()
		local q = mpsc_queue.MpscQueue.new()

		local task = coop.spawn(function()
			return q:pop(), q:pop()
		end)

		assert.is.True(q:empty())

		q:push(1)
		q:push(2)

		assert.is.True(q:empty())

		local first, second = task:await(50, 1)
		assert.are.same(1, first)
		assert.are.same(2, second)
	end)

	it("handles cancellation but continues working", function()
		local q = mpsc_queue.MpscQueue.new()

		local task = coop.spawn(function()
			local _, error = coop.copcall(function()
				return q:pop()
			end)

			return error, q:pop(), q:pop()
		end)

		task:cancel()
		q:push(1)
		q:push(2)

		local error, first, second = task:await(50, 1)

		assert.are.same("cancelled", error)
		assert.are.same(1, first)
		assert.are.same(2, second)
	end)

	describe("pop", function()
		it("throws an error if a second client starts waiting", function()
			local q = mpsc_queue.MpscQueue.new()

			local _ = coop.spawn(function()
				q:pop()
			end)

			assert.has_error(function()
					q:pop()
			end, "Some other task is already waiting for a value.")
		end)

		it("throws an error if not within a task", function()
			local q = mpsc_queue.MpscQueue.new()

			assert.has_error(function()
					q:pop()
			end, "Pop must be called within a task.")
		end)
	end)
end)
