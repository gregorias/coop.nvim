--- Busted tests for coop.table-utils.
local coop = require("coop")
local copcall = require("coop.coroutine-utils").copcall
local uv = require("coop.uv")

describe("coop.future", function()
	describe("Future", function()
		it("completed future’s wait calls the callback immediately", function()
			local future = coop.Future.new()
			future:complete(1, 2)

			local success, f_ret_0, f_ret_1 = false, nil, nil
			future:await(function(...)
				success, f_ret_0, f_ret_1 = ...
			end)
			assert.is.True(success)
			assert.are.same({ 1, 2 }, { f_ret_0, f_ret_1 })
		end)

		describe("await_tf", function()
			it("returns errors like pcall for asynchronously error-ended futures", function()
				local future = coop.Future.new()

				local success, err = true, ""
				coop.spawn(function()
					success, err = copcall(future.await, future)
				end)

				future:set_error("foo")
				assert.is.False(success)
				assert.are.same("foo", err)
			end)
		end)

		describe("wait", function()
			it("throws an error if the future throws an error", function()
				local success, result = pcall(function()
					coop.spawn(function()
						error("foo", 0)
						return "foo"
					end):await(1)
				end)
				assert.is.False(success)
				assert.are.same("foo", result)
			end)

			it("returns nothing if the future is still unfinished", function()
				local result = coop.spawn(function()
					uv.sleep(1000)
					return "foo"
				end):await(1)
				assert.is.Nil(result)
			end)
		end)
	end)
end)
