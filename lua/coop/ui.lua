---@diagnostic disable: undefined-doc-param, undefined-doc-name
--- This module provides task function versions of vim.ui functions.
---
--- Official reference: https://neovim.io/doc/user/lua.html#vim.ui
local M = {}

-- We need to wrap vim.ui functions inside an anonymous functions to enable monkey patching that
-- popular plugins like Dressing use.

---@class Coop.ui.InputOpts
---@field prompt string?
---@field default string?
---@field completion string?
---@field highlight function?

--- Prompts the user for input.
---
--- https://neovim.io/doc/user/lua.html#vim.ui.input()
---
---@async
---@param opts Coop.ui.InputOpts
---@return string?
M.input = function(opts)
	local coop = require("coop")
	return coop.cb_to_tf(function(cb)
		vim.ui.input(opts, cb)
	end)()
end

---@class Coop.ui.SelectOpts
---@field prompt string?
---@field format_item? fun(item: any):string
---@field kind string?

--- Prompts the user to pick from a list of items.
---
--- https://neovim.io/doc/user/lua.html#vim.ui.select()
---
---@async
---@param items any[]
---@param opts Coop.ui.SelectOpts?
---@return any item
---@return integer? idx
M.select = function(items, opts)
	local coop = require("coop")
	opts = opts or {}
	return coop.cb_to_tf(function(cb)
		vim.ui.select(items, opts, cb)
	end)()
end

return M
