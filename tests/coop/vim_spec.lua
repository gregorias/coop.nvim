--- Busted tests for coop.uv.
local coop = require("coop")

describe("coop.vim", function()
	describe("system", function()
		system = require("coop.vim").system

		it("executes cat", function()
			local results = coop.spawn(system, { "cat", "selene.toml" }):await(100, 1)
			assert.are.same(0, results.code)
			assert.are.same(0, results.signal)
			assert.are.same('std = "neovim"\n', results.stdout)
			assert.are.same("", results.stderr)
		end)
	end)
end)
