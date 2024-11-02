--- Busted tests for coop.control
local control = require("coop.control")

describe("coop.control", function()
	describe("await_any", function()
		it("throws on empty list", function()
			assert.has.error(function()
				control.await_any({})
			end, "The list of awaitables is empty.")
		end)
	end)
end)
