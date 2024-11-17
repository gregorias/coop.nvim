--- Busted tests for coop.uv.
local coop = require("coop")
local uv = require("coop.uv")
local uv_utils = require("coop.uv-utils")
local pack = require("coop.table-utils").pack

describe("coop.uv-utils", function()
	describe("sleep", function()
		local sleep = uv_utils.sleep
		it("sleeps for some time in an asynchronous coroutine", function()
			local done = false

			local spawned_task = coop.spawn(function()
				sleep(50)
				done = true
			end)

			-- The timer should not be done yet and should execute asynchronously.
			assert.is.False(done)

			spawned_task:await(100, 20)
			assert.is.True(done)
		end)

		it("works with an vim.api call", function()
			local spawned_task = coop.spawn(function()
				sleep(50)
				return vim.api.nvim_get_current_line()
			end)

			local result = spawned_task:await(100, 20)
			assert.are.same("", result)
		end)

		it("handles cancellation", function()
			local done = false

			local spawned_task = coop.spawn(function()
				sleep(50)
				done = true
			end)
			spawned_task:cancel()

			assert.has.error(function()
				spawned_task:await(1, 2)
			end, "cancelled")
			assert.is.False(done)
		end)
	end)

	describe("Stream Reader & StreamWriter", function()
		it("works with two connected pipes", function()
			local result = coop.spawn(function()
				local fds = vim.uv.pipe({ nonblock = true }, { nonblock = true })
				local sr = uv_utils.StreamReader.from_fd(fds.read)
				local sw = uv_utils.StreamWriter.from_fd(fds.write)

				sw:write("Hello, world!")
				-- Close the writer to signal EOF.
				sw:close()
				local data = sr:read_until_eof()
				sr:close()
				return data
			end):await(20000, 1)

			assert.are.same("Hello, world!", result)
		end)

		it("executes the snippet from Neovim’s docs", function()
			-- The snippet:
			-- https://neovim.io/doc/user/luvref.html#uv.spawn()
			--
			-- This test uses the task API to avoid callbacks.
			local stdin = vim.uv.new_pipe()
			local stdout = vim.uv.new_pipe()
			local stderr = vim.uv.new_pipe()

			local handle, pid, cat_future = uv.spawn("cat", {
				stdio = { stdin, stdout, stderr },
			})
			assert.is.True(handle ~= nil and pid ~= nil)

			local sr = uv_utils.StreamReader.new(stdout)
			local sw = uv_utils.StreamWriter.new(stdin)

			-- We now need to execute in a task to avoid using callbacks and test the API.
			local data, exit_code, exit_signal = coop.spawn(function()
				assert(sw:write("Hello World") == nil)
				sw:close()
				local read_data = sr:read_until_eof()
				local result = pack(cat_future:await())
				return read_data, unpack(result, 1, result.n)
			end):await(100, 1)

			assert.are.same("Hello World", data)
			assert.are.same(0, exit_code)
			assert.are.same(0, exit_signal)
		end)
	end)

	describe("StreamReader", function()
		describe("new", function()
			it("throws error on a non-readable stream", function()
				local stream = vim.uv.new_pipe()
				assert.has.error(function()
					uv_utils.StreamReader.new(stream)
				end, "Can not create a stream reader, because the handle is not readable.")
				vim.uv.close(stream)
			end)
		end)

		describe("read", function()
			it("returns nil on closed stream", function()
				local fds = vim.uv.pipe({ nonblock = true }, { nonblock = true })
				local sr = uv_utils.StreamReader.from_fd(fds.read)

				local r1, r2 = coop.spawn(function()
					uv_utils.StreamWriter.from_fd(fds.write):close()
					return sr:read(), sr:read()
				end):await(10, 1)
				coop.spawn(uv_utils.StreamReader.close, sr)
				assert.are.same({ nil, nil }, { r1, r2 })
			end)
		end)
	end)

	describe("StreamWriter", function()
		it("throws error on a non-writable stream", function()
			local stream = vim.uv.new_pipe()
			assert.has.error(function()
				uv_utils.StreamWriter.new(stream)
			end, "Can not create a stream writer, because the handle is not writable.")
			vim.uv.close(stream)
		end)
	end)
end)
