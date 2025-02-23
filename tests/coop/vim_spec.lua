--- Busted tests for coop.uv.
local coop = require("coop")

describe("coop.vim", function()
	describe("system", function()
		local system = require("coop.vim").system

		it("executes cat", function()
			local results = coop.spawn(system, { "cat", "selene.toml" }):await(100, 1)
			assert.are.same(0, results.code)
			assert.are.same(0, results.signal)
			assert.are.same('std = "neovim"\n', results.stdout)
			assert.are.same("", results.stderr)
		end)

		it("executes continuation outside of Lua loop", function()
			local results = coop.spawn(function()
				system({ "cat", "selene.toml" })
				-- nvim_buf_is_loaded can not be called from the Lua loop.
				return vim.api.nvim_buf_is_loaded(0)
			end):await(100, 1)
			assert.are.same(true, results)
		end)
	end)
end)
