--- Busted tests for coop.coroutine-utils.
local coop = require("coop")
local uv = require("coop.uv")
local coroutine_utils = require("coop.coroutine-utils")
local copcall = coroutine_utils.copcall

describe("coop.coroutine-utils", function()
	describe("copcall", function()
		it("executes a throwing coroutine function in a protected mode", function()
			local throw_after_sleep = function()
				uv.sleep(2)
				error("error", 0)
			end
			local f_co = function()
				return copcall(throw_after_sleep)
			end

			local success, err_msg = coop.spawn(f_co):wait(5, 1)

			assert.is.False(success)
			assert.are.same("error", err_msg)
		end)

		it("executes a successful coroutine function in a protected mode", function()
			local throw_after_sleep = function()
				uv.sleep(2)
				return "foo"
			end
			local f_co = function()
				return copcall(throw_after_sleep)
			end

			local success, val = coop.spawn(f_co):wait(5, 1)

			assert.is.True(success)
			assert.are.same("foo", val)
		end)
	end)
end)
