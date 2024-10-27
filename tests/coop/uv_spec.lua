--- Busted tests for coop.uv.
local coop = require("coop")
local uv = require("coop.uv")

describe("coop.uv", function()
	describe("sleep", function()
		it("sleeps for some time in an asynchronous coroutine", function()
			local done = false

			coop.spawn(function()
				uv.sleep(50)
				done = true
			end)

			-- The timer should not be done yet and should execute asynchronously.
			assert.is_false(done)

			vim.wait(100, function()
				return done
			end, 20)
			assert.is_true(done)
		end)
	end)
end)
