--- Busted tests for coop.table-utils.
local coop = require("coop")

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

		describe("await", function()
			it("returns errors like pcall for asynchronously error-ended futures", function()
				local future = coop.Future.new()

				local success, err = true, ""
				coop.spawn(function()
					success, err = future:await()
				end)

				future:set_error("foo")
				assert.is.False(success)
				assert.are.same("foo", err)
			end)
		end)
	end)
end)
