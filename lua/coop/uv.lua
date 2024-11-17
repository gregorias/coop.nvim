---@diagnostic disable: undefined-doc-param, undefined-doc-name
--- This module provides task function versions of vim.uv functions.
---
--- Official reference: https://neovim.io/doc/user/luvref.html.
local M = {}

local coop = require("coop")

-- Types seen in the official reference.

---@alias buffer string|string[]

---@alias uv_req_t uv_fs_t|uv_shutdown_t
---@class uv_fs_t
---@class uv_shutdown_t

-- https://neovim.io/doc/user/luvref.html#luv-contents

---@alias uv_handle_t uv_timer_t|uv_prepare_t|uv_check_t|uv_idle_t|uv_async_t|uv_poll_t|uv_signal_t|uv_process_t|uv_stream_t|uv_udp_t|uv_fs_event_t|uv_fs_pool_t
---@class uv_timer_t userdata
---@class uv_prepare_t userdata
---@class uv_check_t userdata
---@class uv_idle_t userdata
---@class uv_async_t userdata
---@class uv_poll_t userdata
---@class uv_signal_t userdata
---@class uv_process_t userdata
---@alias uv_stream_t uv_tcp_t|uv_pipe_t|uv_tty_t|userdata
---@class uv_tcp_t userdata
---@class uv_pipe_t userdata
---@class uv_tty_t userdata
---@class uv_udp_t userdata
---@alias uv_fs_event_t userdata
---@alias uv_fs_pool_t userdata

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

--- https://neovim.io/doc/user/luvref.html#uv.close()
---
---@async
---@param handle uv_handle_t
M.close = wrap(vim.uv.close)

--- https://neovim.io/doc/user/luvref.html#uv.timer_start()
---
---@async
---@param timer uv_timer_t
---@param timeout integer
---@return integer? zero_or_fail
---@return string? err
---@return string? err_name
M.timer_start = function(timer, timeout)
	-- Repeat must always be zero, because Coopification only involves continuations.
	local timer_start_cb = function(cb, timer_, timeout_)
		local zero, err, err_name = vim.uv.timer_start(timer_, timeout_, 0, function()
			vim.schedule_wrap(cb)(0)
		end)

		if zero == nil then
			-- I don’t know how to simulate this error case.
			cb(zero, err, err_name)
		end
	end

	return coop.cb_to_tf(timer_start_cb)(timer, timeout)
end

--- Spawns a new process.
---
---@param path string The path to the executable.
---@param options table
---@return uv_process_t handle
---@return integer pid
---@return Future future The future for the exit code and signal.
M.spawn = function(path, options)
	local future = coop.Future.new()
	local handle, pid = vim.uv.spawn(path, options, function(code, signal)
		future:complete(code, signal)
	end)
	return handle, pid, future
end

--- vim.uv.process_kill is already synchronous.

--- https://neovim.io/doc/user/luvref.html#uv.shutdown()
---
---@async
---@param stream uv_stream_t
---@return string? err
---@return string? err_name
M.shutdown = function(stream)
	local shutdown_cb = function(cb, stream_)
		local uv_shutdown, err, name = vim.uv.shutdown(stream_, function(err_)
			vim.schedule_wrap(cb)(err_)
		end)
		if uv_shutdown == nil then
			cb(err, name)
		end
		return uv_shutdown, err, name
	end

	return coop.cb_to_tf(shutdown_cb, {
		on_cancel = function(_, write_cb_ret)
			vim.uv.cancel(write_cb_ret[1])
		end,
	})(stream)
end

--- https://neovim.io/doc/user/luvref.html#uv.write()
---
---@async
---@param stream uv_stream_t
---@param data buffer
---@return string? err
---@return string? err_name
M.write = function(stream, data)
	local write_cb = function(cb, stream_, data_)
		local handle, err, err_name = vim.uv.write(stream_, data_, function(err_)
			-- vim.uv functions require a rescheduled callback to run `vim.api` functions.
			vim.schedule_wrap(cb)(err_)
		end)
		if handle == nil then
			-- Immediately call the callback to handle the error, so that
			-- the cancellation mechanism below never triggers.
			cb(err, err_name)
		else
			return handle
		end
	end
	return coop.cb_to_tf(write_cb, {
		on_cancel = function(_, write_cb_ret)
			vim.uv.close(write_cb_ret[1])
		end,
	})(stream, data)
end

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
---
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

--- https://neovim.io/doc/user/luvref.html#uv.fs_fsync()
---
---@async
---@param fd integer
---@return string? err
---@return boolean? success
M.fs_fsync = wrap(vim.uv.fs_fsync)

--- https://neovim.io/doc/user/luvref.html#uv.fs_access()
---
---@async
---@param path string
---@param mode integer
---@return string? err
---@return boolean? permission
M.fs_access = wrap(vim.uv.fs_access)

--- https://neovim.io/doc/user/luvref.html#uv.fs_chmod()
---
---@async
---@param path string
---@param mode integer
---@return string? err
---@return boolean? success
M.fs_chmod = wrap(vim.uv.fs_chmod)

--- https://neovim.io/doc/user/luvref.html#uv.fs_fchmod()
---
---@async
---@param fd integer
---@param mode integer
---@return string? err
---@return boolean? success
M.fs_fchmod = wrap(vim.uv.fs_fchmod)

--- https://neovim.io/doc/user/luvref.html#uv.fs_utime()
---
---@async
---@param path string
---@param atime integer
---@param mtime integer
---@return string? err
---@return boolean? success
M.fs_utime = wrap(vim.uv.fs_utime)

--- https://neovim.io/doc/user/luvref.html#uv.fs_link()
---
---@async
---@param path string
---@param new_path string
---@return string? err
---@return boolean? success
M.fs_link = wrap(vim.uv.fs_link)

--- https://neovim.io/doc/user/luvref.html#uv.fs_symlink()
---
---@async
---@param path string
---@param new_path string
---@param flags? table|integer
---@return string? err
---@return boolean? success
M.fs_symlink = wrap(vim.uv.fs_symlink)

--- https://neovim.io/doc/user/luvref.html#uv.fs_readlink()
---
---@async
---@param path string
---@return string? err
---@return string? path
M.fs_readlink = wrap(vim.uv.fs_readlink)

--- https://neovim.io/doc/user/luvref.html#uv.fs_realpath()
---
---@async
---@param path string
M.fs_realpath = wrap(vim.uv.fs_realpath)

--- https://neovim.io/doc/user/luvref.html#uv.fs_chown()
---
---@async
---@param path string
---@param uid integer
---@param gid integer
---@return string? err
---@return boolean? success
M.fs_chown = wrap(vim.uv.fs_chown)

--- https://neovim.io/doc/user/luvref.html#uv.fs_fchown()
---
---@async
---@param fd integer
---@param uid integer
---@param gid integer
M.fs_fchown = wrap(vim.uv.fs_fchown)

--- https://neovim.io/doc/user/luvref.html#uv.fs_lchown()
---
---@async
---@param fd integer
---@param uid integer
---@param gid integer
M.fs_lchown = wrap(vim.uv.fs_lchown)

--- https://neovim.io/doc/user/luvref.html#uv.fs_copyfile()
---
---@async
---@param path string
---@param new_path string
---@param flags? table|integer
M.fs_copyfile = wrap(vim.uv.fs_copyfile)

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
