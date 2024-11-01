--- Busted tests for coop.coroutine-utils.
local coop = require("coop")
local uv = require("coop.uv")
local coroutine_utils = require("coop.coroutine-utils")
local copcall = coroutine_utils.copcall

describe("coop.coroutine-utils", function()
	describe("copcall", function()
		it("executes a throwing coroutine function in a protected mode", function()
			local throw_after_sleep = function()
				uv.sleep(10)
				error("error", 0)
			end
			local f_co = function()
				local success, err_msg = copcall(throw_after_sleep)
				return success, err_msg
			end

			local success, err_msg = coop.spawn(f_co):wait(30, 10)

			assert.is.False(success)
			assert.are.same("error", err_msg)
		end)
	end)
end)
