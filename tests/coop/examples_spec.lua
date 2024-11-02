--- Busted tests for coop.examples
local coop = require("coop")
local examples = require("coop.examples")

describe("coop.examples", function()
	it("search_for_readme works", function()
		local success, size = coop.spawn(examples.search_for_readme):await(100, 1)
		assert.is.True(success)
		assert.is.True(size > 0)
	end)

	it("sort_with_time works", function()
		local results = coop.spawn(examples.sort_with_time, { 20, 40, 10, 30 }):await(100, 20)
		assert.are.same({ 10, 20, 30, 40 }, results)
	end)
end)
