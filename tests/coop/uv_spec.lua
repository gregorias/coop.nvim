--- Busted tests for coop.uv.
local coop = require("coop")
local uv = require("coop.uv")

describe("coop.uv", function()
	describe("sleep", function()
		it("sleeps for some time in an asynchronous coroutine", function()
			local done = false

			local future = coop.spawn(function()
				uv.sleep(50)
				done = true
			end)

			-- The timer should not be done yet and should execute asynchronously.
			assert.is.False(done)

			future:wait(100, 20)
			assert.is.True(done)
		end)
	end)
end)
