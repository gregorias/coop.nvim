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

	describe("spawn", function()
		it("executes the snippet from Neovim’s docs", function()
			-- The snippet:
			-- https://neovim.io/doc/user/luvref.html#uv.spawn():~:text=local%20stdin%20%3D%20uv.new_pipe,end)%0Aend)
			--
			-- This test uses the task API to avoid callbacks.
			local stdin = vim.uv.new_pipe()
			local stdout = vim.uv.new_pipe()
			local stderr = vim.uv.new_pipe()

			local handle, pid, cat_future = uv.spawn("cat", {
				stdio = { stdin, stdout, stderr },
			})
			assert.is.True(handle ~= nil and pid ~= nil)

			local read_future = coop.Future.new()
			vim.uv.read_start(stdout, function(err, data)
				assert(not err, err)
				if data ~= nil and not read_future.done then
					read_future:complete(data)
				end
			end)
			vim.uv.write(stdin, "Hello World")

			-- We now need to execute in a task to avoid using callbacks and test the API.
			local exit_code, exit_signal = coop.spawn(function()
				local read_data = read_future:await()
				assert.are.same("Hello World", read_data)
				local err_stdin_shutdown = uv.shutdown(stdin)
				assert.is.Nil(err_stdin_shutdown)
				return cat_future:await()
			end):await(200, 2)

			assert.are.same(0, exit_code)
			assert.are.same(0, exit_signal)
		end)
	end)

	describe("write", function()
		it("returns a fail on a non-writable pipe", function()
			local p = vim.uv.new_pipe()

			local err = coop.spawn(function()
				return uv.write(p, "foo")
			end):await(100, 1)

			assert.are.same("EBADF: bad file descriptor", err)
		end)

		it("cancellation works", function()
			local fds = vim.uv.pipe({ nonblock = true }, { nonblock = true })
			local read_pipe = vim.uv.new_pipe()
			read_pipe:open(fds.read)
			local write_pipe = vim.uv.new_pipe()
			write_pipe:open(fds.write)

			coop.spawn(function()
				return uv.write(write_pipe, "foo")
			end):cancel()

			if not vim.uv.is_closing(write_pipe) then
				vim.uv.close(write_pipe)
			end
			vim.uv.close(read_pipe)
		end)

		it("writes to a pipe", function()
			local fds = vim.uv.pipe({ nonblock = true }, { nonblock = true })
			local read_pipe = vim.uv.new_pipe()
			read_pipe:open(fds.read)
			local write_pipe = vim.uv.new_pipe()
			write_pipe:open(fds.write)

			local read_future = coop.Future.new()

			read_pipe:read_start(function(err, data)
				if read_future.done then
					error("This should not happen.")
				end
				if err then
					read_future:error(err)
				else
					read_future:complete(data)
				end
			end)

			local result = coop.spawn(function()
				local err = uv.write(write_pipe, "foo")
				assert(err == nil)
				return read_future:await()
			end):await(100, 1)

			vim.uv.close(write_pipe)
			vim.uv.close(read_pipe)

			assert.are.same("foo", result)
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
