--- Busted tests for coop.subprocess.
local coop = require("coop")
local subprocess = require("coop.subprocess")

describe("coop.subprocess", function()
	it("can chain subprocess I/O", function()
		local result = coop.spawn(function()
			local first_cat = subprocess.spawn("cat", {
				stdio = { subprocess.STREAM, subprocess.PIPE },
			})
			local second_cat = subprocess.spawn("cat", {
				stdio = { first_cat.stdout, subprocess.STREAM },
			})

			first_cat.stdin:write("Hello, world!")
			first_cat.stdin:close()
			local data = second_cat.stdout:read_until_eof()
			first_cat:await()
			second_cat:await()
			return data
		end):await(100, 1)

		assert.are.same("Hello, world!", result)
	end)

	it("passes args to printf", function()
		local result = coop.spawn(function()
			local printf = subprocess.spawn("printf", {
				args = { "Hello, world!" },
				stdio = { nil, subprocess.PIPE },
			})
			local cat = subprocess.spawn("cat", {
				stdio = { printf.stdout, subprocess.STREAM },
			})

			local data = cat.stdout:read_until_eof()

			printf:await()
			cat:await()

			return data
		end):await(100, 1)

		assert.are.same("Hello, world!", result)
	end)

	it("forwards to stderr", function()
		local result = coop.spawn(function()
			local ls = subprocess.spawn("ls", {
				args = { "asdf" },
				stdio = { nil, nil, subprocess.STREAM },
			})
			local err_msg = ls.stderr:read_until_eof()
			ls:await()
			return err_msg
		end):await(10000, 1)

		assert.are.same("ls: asdf: No such file or directory\n", result)
	end)

	it("kill kills", function()
		local result = coop.spawn(function()
			local ls = subprocess.spawn("sleep", {
				args = { "60" },
			})
			ls:kill()
			ls:await()
			return "done"
		end):await(1000, 1)
		-- Using shorter timeout than the sleep duration to test the kill.

		assert.are.same("done", result)
	end)
end)
