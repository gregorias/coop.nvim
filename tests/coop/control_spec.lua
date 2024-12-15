--- Busted tests for coop.control
local coop = require("coop")
local control = require("coop.control")
local sleep = require("coop.uv-utils").sleep

describe("coop.control", function()
	describe("gather", function()
		it("works with empty input", function()
			assert.are.same({}, coop.spawn(control.gather, {}):await(100, 1))
		end)

		it("works with multiple results", function()
			local t = coop.spawn(function()
				return true, "foo"
			end)

			local gather_t = coop.spawn(control.gather, { t })
			local results = gather_t:await(100, 1)
			assert.are.same({ { true, "foo" } }, results)
		end)

		it("cancel cancels subtasks and returns cancellation error", function()
			local sleep_t = coop.spawn(sleep, 100)

			local gather_t = coop.spawn(control.gather, { sleep_t })
			gather_t:cancel()

			assert.is.True(gather_t:is_cancelled())
			assert.is.True(sleep_t:is_cancelled())
		end)

		it("error from a subtask makes gather throw", function()
			local sleep_t = coop.spawn(sleep, 200)
			local result_t = coop.spawn(function()
				sleep(10)
				error("foo")
			end)

			local gather_t = coop.spawn(control.gather, { sleep_t, result_t })

			assert.has.error(function()
				gather_t:await(100, 1)
			end, "foo")
		end)
	end)

	describe("await_any", function()
		it("throws on empty list", function()
			assert.has.error(function()
				control.await_any({})
			end, "The list of awaitables is empty.")
		end)
	end)

	describe("await_all", function()
		it("works with immediately finished futures", function()
			local future = coop.Future.new()
			future:complete("foo")

			local results = nil
			coop.spawn(function()
				results = coop.await_all({ future })
			end)

			assert.are.same({ { true, "foo" } }, results)
		end)

		it("works with delayed futures", function()
			local future_1, future_2 = coop.Future.new(), coop.Future.new()

			local results = nil
			coop.spawn(function()
				results = coop.await_all({ future_1, future_2 })
			end)

			future_1:complete("foo")
			future_2:complete("bar")

			assert.are.same({ { true, "foo" }, { true, "bar" } }, results)
		end)

		it("returns immediately on receiving an empty list", function()
			local result = coop.spawn(function()
				return coop.await_all({})
			end):await()

			assert.are.same({}, result)
		end)

		it("throws if done outside a task", function()
			assert.has.error(function()
				coop.await_all({ coop.Future.new() })
			end, "await_all can only be used in a task.")
		end)
	end)
end)
