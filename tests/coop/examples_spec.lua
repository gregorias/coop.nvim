--- Busted tests for coop.examples
local coop = require("coop")
local examples = require("coop.examples")

describe("coop.examples", function()
	describe("sort_with_time", function()
		local results = coop.spawn(examples.sort_with_time, { 20, 40, 10, 30 }):wait(100, 20)
		assert.are.same({ 10, 20, 30, 40 }, results)
	end)
end)
