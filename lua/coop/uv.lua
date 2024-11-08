--- This module provides task function versions of vim.uv functions.
local M = {}

local coop = require("coop")

--- Wraps the callback param with `vim.schedule_wrap`.
---
--- This is useful for Libuv functions to ensure that their continuations can run `vim.api` functions without problems.
---
---@param f function
---@param cb_pos? number|string the position of the callback parameter
---@return function
local schedule_cb = function(f, cb_pos)
	cb_pos = cb_pos or "last"

	return function(cb, ...)
		local pack = require("coop.table-utils").pack
		local unpack = require("coop.table-utils").unpack_packed
		local safe_insert = require("coop.table-utils").safe_insert
		local args = pack(...)
		if cb_pos == "last" then
			cb_pos = select("#", ...) + 1
		end
		---@diagnostic disable-next-line: param-type-mismatch
		safe_insert(args, cb_pos, args.n, vim.schedule_wrap(cb))
		args.n = args.n + 1
		f(unpack(args))
	end
end

--- Wraps a Libuv function into a task function.
---
---@param f function
---@param cb_pos? number|string the position of the callback parameter
---@return function tf
local wrap = function(f, cb_pos)
	return coop.cb_to_tf(schedule_cb(f, cb_pos))
end

M.timer_start = wrap(vim.uv.timer_start)
M.fs_open = wrap(vim.uv.fs_open)
M.fs_close = wrap(vim.uv.fs_close)
M.fs_fstat = wrap(vim.uv.fs_fstat)
M.fs_opendir = wrap(vim.uv.fs_opendir, 2)
M.fs_readdir = wrap(vim.uv.fs_readdir)
M.fs_closedir = wrap(vim.uv.fs_closedir)

--- Sleeps for a number of milliseconds.
---
---@async
---@param ms number The number of milliseconds to sleep.
M.sleep = function(ms)
	local timer = vim.uv.new_timer()
	M.timer_start(timer, ms, 0)
	timer:stop()
	timer:close()
end

return M
