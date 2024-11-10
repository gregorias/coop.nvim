---@diagnostic disable: undefined-doc-param, undefined-doc-name
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

M.timer_start = wrap(vim.uv.timer_start)

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

--- TODO: Not implementing stream functions for now.
--- I’ll wait for initial feedback on the framework before spending time here.
--- https://neovim.io/doc/user/luvref.html#uv.shutdown()

--- https://neovim.io/doc/user/luvref.html#uv.fs_event_start()
--- https://neovim.io/doc/user/luvref.html#uv.fs_poll_start()
--- Don’t import, because the callback is not a continuation.

--- https://neovim.io/doc/user/luvref.html#uv.fs_close()
---@async
---@param fd integer
---@return string? err
---@return boolean? success
M.fs_close = wrap(vim.uv.fs_close)

--- https://neovim.io/doc/user/luvref.html#uv.fs_open()
---@async
---@param path string
---@param flags string|integer
---@param mode integer
---@return string? err
---@return integer? fd
M.fs_open = wrap(vim.uv.fs_open, {
	cleanup = function(err, fd)
		if not err then
			vim.uv.fs_close(fd)
		end
	end,
})

--- https://neovim.io/doc/user/luvref.html#uv.fs_read()
---
---@async
---@param fd integer
---@param size integer
---@param offset? integer
---@return string? err
---@return string? data
M.fs_read = wrap(vim.uv.fs_read)

--- https://neovim.io/doc/user/luvref.html#uv.fs_unlink()
---
---@async
---@param path string
---@return string? err
---@return boolean? success
M.fs_unlink = wrap(vim.uv.fs_unlink)

--- https://neovim.io/doc/user/luvref.html#uv.fs_write()
---
---@async
---@param fd integer
---@param data string
---@param offset? integer
---@return string? err
---@return integer? bytes
M.fs_write = wrap(vim.uv.fs_write)

--- https://neovim.io/doc/user/luvref.html#uv.fs_mkdir()
---
---@async
---@param path string
---@param mode integer
---@return string? err
---@return boolean? success
M.fs_mkdir = wrap(vim.uv.fs_mkdir)

--- https://neovim.io/doc/user/luvref.html#uv.fs_rmdir()
---
---@async
---@param path string
---@return string? err
---@return boolean? success
M.fs_rmdir = wrap(vim.uv.fs_rmdir)

--- https://neovim.io/doc/user/luvref.html#uv.fs_scandir()
---
---@async
---@param path string
---@return string? err
---@return uv_fs_t? success
M.fs_scandir = wrap(vim.uv.fs_scandir)

--- https://neovim.io/doc/user/luvref.html#uv.fs_stat()
---
---@async
---@param path string
---@return string? err
---@return table? stat
M.fs_stat = wrap(vim.uv.fs_stat)

--- https://neovim.io/doc/user/luvref.html#uv.fs_fstat()
---
---@async
---@param fd integer
---@return string? err
---@return table? stat
M.fs_fstat = wrap(vim.uv.fs_fstat)

--- https://neovim.io/doc/user/luvref.html#uv.fs_lstat()
---
---@async
---@param fd integer
---@return string? err
---@return table? stat
M.fs_lstat = wrap(vim.uv.fs_lstat)

--- https://neovim.io/doc/user/luvref.html#uv.fs_rename()
---
---@async
---@param path string
---@param new_path string
---@return string? err
---@return boolean? success
M.fs_rename = wrap(vim.uv.fs_rename)

--- https://neovim.io/doc/user/luvref.html#uv.fs_chown()
---
---@async
---@param path string
---@param uid integer
---@param gid integer
---@return string? err
---@return boolean? success
M.fs_chown = wrap(vim.uv.fs_chown)

--- https://neovim.io/doc/user/luvref.html#uv.fs_opendir()
---
---@async
---@param path string
---@param entries? integer
---@return string? err
---@return luv_dir_t? dir
M.fs_opendir = wrap(vim.uv.fs_opendir, {
	cleanup = function(err, dir)
		if not err then
			vim.uv.fs_closedir(dir)
		end
	end,
}, 2)

--- https://neovim.io/doc/user/luvref.html#uv.fs_readdir()
---
---@async
---@param dir luv_dir_t
---@return string? err
---@return table? entries
M.fs_readdir = wrap(vim.uv.fs_readdir)

--- https://neovim.io/doc/user/luvref.html#uv.fs_closedir()
---
---@async
---@param dir luv_dir_t
---@return string? err
---@return boolean? success
M.fs_closedir = wrap(vim.uv.fs_closedir)

--- https://neovim.io/doc/user/luvref.html#uv.fs_statfs()
---
---@async
---@param path string
---@return string? err
---@return table? statfs
M.fs_statfs = wrap(vim.uv.fs_statfs)

return M
