--- This module provides task function versions of vim.uv functions.
---
--- Official reference: https://neovim.io/doc/user/luvref.html.
local M = {}

local coop = require("coop")
local copcall = require("coop").copcall

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
---@param cb2tf_opts? CbToTfOpts
---@param cb_pos? number|string the position of the callback parameter
---@return async function tf
local wrap = function(f, cb2tf_opts, cb_pos)
	return coop.cb_to_tf(schedule_cb(f, cb_pos), cb2tf_opts)
end

--- https://neovim.io/doc/user/luvref.html#uv.poll_start()
--- Don’t import, because the callback is not a continuation.

-- TODO: https://neovim.io/doc/user/luvref.html#uv.shutdown()

M.timer_start = wrap(vim.uv.timer_start)
M.fs_open = wrap(vim.uv.fs_open, {
	cleanup = function(err, fd)
		if not err then
			vim.uv.fs_close(fd)
		end
	end,
})
M.fs_close = wrap(vim.uv.fs_close)
M.fs_fstat = wrap(vim.uv.fs_fstat)
M.fs_opendir = wrap(vim.uv.fs_opendir, {
	cleanup = function(err, dir)
		if not err then
			vim.uv.fs_closedir(dir)
		end
	end,
}, 2)
M.fs_readdir = wrap(vim.uv.fs_readdir)
M.fs_closedir = wrap(vim.uv.fs_closedir)

--- Sleeps for a number of milliseconds.
---
---@async
---@param ms number The number of milliseconds to sleep.
M.sleep = function(ms)
	local timer = vim.uv.new_timer()
	local success, err = copcall(M.timer_start, timer, ms, 0)
	-- Safely close resources even in case of a cancellation error.
	timer:stop()
	timer:close()
	if not success then
		error(err, 0)
	end
end

return M
