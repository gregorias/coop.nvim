--- Busted tests for coop.table-utils.
local functional_utils = require("coop.functional-utils")

describe("coop.functional_utils", function()
	describe("shift_parameters", function()
		it("shifts the parameters to the right", function()
			local f = function(a, b, c)
				return a, b, c
			end
			local shifted_f = functional_utils.shift_parameters(f)

			assert.are.same({ 1, 2, "cb" }, { shifted_f("cb", 1, 2) })
		end)
	end)
end)
