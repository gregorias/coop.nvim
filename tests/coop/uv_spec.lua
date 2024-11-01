--- Busted tests for coop.uv.
local coop = require("coop")
local uv = require("coop.uv")

describe("coop.uv", function()
	describe("sleep", function()
		it("sleeps for some time in an asynchronous coroutine", function()
			local done = false

			local spawned_task = coop.spawn(function()
				uv.sleep(50)
				done = true
			end)

			-- The timer should not be done yet and should execute asynchronously.
			assert.is.False(done)

			spawned_task:wait(100, 20)
			assert.is.True(done)
		end)

		it("works with an vim.api call", function()
			local spawned_task = coop.spawn(function()
				uv.sleep(50)
				return vim.api.nvim_get_current_line()
			end)

			local result = spawned_task:wait(100, 20)
			assert.are.same("", result)
		end)
	end)
end)
