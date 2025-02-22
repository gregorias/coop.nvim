---@diagnostic disable: duplicate-set-field
--- Busted tests for coop.ui.
local coop = require("coop")
local ui = require("coop.ui")

describe("coop.ui", function()
	describe("input", function()
		it("works", function()
			vim.ui.input = function(_, cb)
				cb("foo")
			end

			local result = coop.spawn(function()
				return ui.input({ prompt = "Insert text:" })
			end):await(200, 2)

			assert.are.same("foo", result)
		end)
	end)

	describe("select", function()
		it("works", function()
			vim.ui.select = function(items, _, cb)
				if #items > 0 then
					cb(items[1], 1)
				else
					cb(nil, nil)
				end
			end

			local item, idx = coop.spawn(function()
				return ui.select({ "foo", "bar" }, { prompt = "Select an item:" })
			end):await(200, 2)
			assert.are.same("foo", item)
			assert.are.same(1, idx)
		end)
	end)
end)
