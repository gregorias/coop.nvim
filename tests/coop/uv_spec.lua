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

			spawned_task:await(100, 20)
			assert.is.True(done)
		end)

		it("works with an vim.api call", function()
			local spawned_task = coop.spawn(function()
				uv.sleep(50)
				return vim.api.nvim_get_current_line()
			end)

			local result = spawned_task:await(100, 20)
			assert.are.same("", result)
		end)

		it("handles cancellation", function()
			local done = false

			local spawned_task = coop.spawn(function()
				uv.sleep(50)
				done = true
			end)
			spawned_task:cancel()

			assert.has.error(function()
				spawned_task:await(1, 2)
			end, "cancelled")
			assert.is.False(done)
		end)
	end)

	describe("fs_read", function()
		it("reads README", function()
			local header = coop.spawn(function()
				local err_open, fd = uv.fs_open("README.md", "r", 0)
				assert.is.Nil(err_open)
				local err_read, data = uv.fs_read(fd, 4)
				assert.is.Nil(err_read)
				uv.fs_close(fd)
				return data
			end):await(100, 2)

			-- The readme starts with an HTML comment.
			assert.are.same("<!--", header)
		end)
	end)
end)
