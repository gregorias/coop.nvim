--- Busted tests for coop.control
local coop = require("coop")
local control = require("coop.control")

describe("coop.control", function()
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
