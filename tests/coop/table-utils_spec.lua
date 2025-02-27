--- Busted tests for coop.table-utils.
local table_utils = require("coop.table-utils")

describe("coop.table-utils", function()
	describe("replicate", function()
		local replicate = table_utils.replicate
		it("works", function()
			assert.are.same({}, replicate(0, nil))
			assert.are.same({ "foo", "foo", "foo" }, replicate(3, "foo"))
			assert.has.error(function()
				replicate(-1, "foo")
			end, "Can't replicate a value a negative number of times: -1.")
		end)
	end)

	describe("shift_left", function()
		it("shifts the elements of a list to the left", function()
			local t = { 1, 2, 3, 4, 5 }

			table_utils.shift_left(t, #t)

			assert.are.same({ 2, 3, 4, 5, 1 }, t)
		end)

		it("returns the list unchanged if it is empty", function()
			assert.are.same({}, table_utils.shift_left({}, 0))
		end)
	end)

	describe("shift_right", function()
		it("shifts the elements of a list to the right", function()
			local t = { 1, 2, 3, 4, 5 }

			table_utils.shift_right(t, 5)

			assert.are.same({ 5, 1, 2, 3, 4 }, t)
		end)

		it("returns the list unchanged if it is empty", function()
			assert.are.same({}, table_utils.shift_right({}, 0))
		end)
	end)
end)
