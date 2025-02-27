---@diagnostic disable: undefined-doc-param, undefined-doc-name
--- This module provides task function versions of vim.uv functions.
---
--- Official reference: https://neovim.io/doc/user/luvref.html.
local M = {}

local coop = require("coop")

-- Types seen in the official reference.

---@alias buffer string|string[]

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
---@param cb2tf_opts? Coop.CbToTfOpts
---@param cb_pos? number|string the position of the callback parameter
---@return async function tf
local wrap = function(f, cb2tf_opts, cb_pos)
	return coop.cb_to_tf(schedule_cb(f, cb_pos), cb2tf_opts)
end

--- https://neovim.io/doc/user/luvref.html#uv.close()
---
---@async
---@param handle uv.uv_handle_t
M.close = function(handle)
	return wrap(vim.uv.close)(handle)
end

--- https://neovim.io/doc/user/luvref.html#uv.timer_start()
---
---@async
---@param timer uv.uv_timer_t
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
---@return uv.uv_process_t handle
---@return integer pid
---@return Coop.Future future The future for the exit code and signal.
M.spawn = function(path, options)
	local future = coop.Future.new()
	local handle, pid = vim.uv.spawn(
		path,
		options,
		vim.schedule_wrap(function(code, signal)
			future:complete(code, signal)
		end)
	)
	return handle, pid, future
end

--- vim.uv.process_kill is already synchronous.

--- https://neovim.io/doc/user/luvref.html#uv.shutdown()
---
---@async
---@param stream uv.uv_stream_t
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
---@param stream uv.uv_stream_t
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
M.fs_close = function(fd)
	return wrap(vim.uv.fs_close)(fd)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_open()
---
---@async
---@param path string
---@param flags string|integer
---@param mode integer
---@return string? err
---@return integer? fd
M.fs_open = function(path, flags, mode)
	return wrap(vim.uv.fs_open, {
		cleanup = function(err, fd)
			if not err then
				vim.uv.fs_close(fd)
			end
		end,
	})(path, flags, mode)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_read()
---
---@async
---@param fd integer
---@param size integer
---@param offset? integer
---@return string? err
---@return string? data
M.fs_read = function(fd, size, offset)
	return wrap(vim.uv.fs_read)(fd, size, offset)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_unlink()
---
---@async
---@param path string
---@return string? err
---@return boolean? success
M.fs_unlink = function(path)
	return wrap(vim.uv.fs_unlink)(path)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_write()
---
---@async
---@param fd integer
---@param data string
---@param offset? integer
---@return string? err
---@return integer? bytes
M.fs_write = function(fd, data, offset)
	return wrap(vim.uv.fs_write)(fd, data, offset)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_mkdir()
---
---@async
---@param path string
---@param mode integer
---@return string? err
---@return boolean? success
M.fs_mkdir = function(path, mode)
	return wrap(vim.uv.fs_mkdir)(path, mode)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_rmdir()
---
---@async
---@param path string
---@return string? err
---@return boolean? success
M.fs_rmdir = function(path)
	return wrap(vim.uv.fs_rmdir)(path)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_scandir()
---
---@async
---@param path string
---@return string? err
---@return uv.uv_fs_t? success
M.fs_scandir = function(path)
	return wrap(vim.uv.fs_scandir)(path)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_stat()
---
---@async
---@param path string
---@return string? err
---@return table? stat
M.fs_stat = function(path)
	return wrap(vim.uv.fs_stat)(path)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_fstat()
---
---@async
---@param fd integer
---@return string? err
---@return table? stat
M.fs_fstat = function(fd)
	return wrap(vim.uv.fs_fstat)(fd)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_lstat()
---
---@async
---@param fd integer
---@return string? err
---@return table? stat
M.fs_lstat = function(fd)
	return wrap(vim.uv.fs_lstat)(fd)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_rename()
---
---@async
---@param path string
---@param new_path string
---@return string? err
---@return boolean? success
M.fs_rename = function(path, new_path)
	return wrap(vim.uv.fs_rename)(path, new_path)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_fsync()
---
---@async
---@param fd integer
---@return string? err
---@return boolean? success
M.fs_fsync = function(fd)
	return wrap(vim.uv.fs_fsync)(fd)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_access()
---
---@async
---@param path string
---@param mode integer
---@return string? err
---@return boolean? permission
M.fs_access = function(path, mode)
	return wrap(vim.uv.fs_access)(path, mode)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_chmod()
---
---@async
---@param path string
---@param mode integer
---@return string? err
---@return boolean? success
M.fs_chmod = function(path, mode)
	return wrap(vim.uv.fs_chmod)(path, mode)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_fchmod()
---
---@async
---@param fd integer
---@param mode integer
---@return string? err
---@return boolean? success
M.fs_fchmod = function(fd, mode)
	return wrap(vim.uv.fs_fchmod)(fd, mode)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_utime()
---
---@async
---@param path string
---@param atime integer
---@param mtime integer
---@return string? err
---@return boolean? success
M.fs_utime = function(path, atime, mtime)
	return wrap(vim.uv.fs_utime)(path, atime, mtime)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_link()
---
---@async
---@param path string
---@param new_path string
---@return string? err
---@return boolean? success
M.fs_link = function(path, new_path)
	return wrap(vim.uv.fs_link)(path, new_path)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_symlink()
---
---@async
---@param path string
---@param new_path string
---@param flags? table|integer
---@return string? err
---@return boolean? success
M.fs_symlink = function(path, new_path, flags)
	return wrap(vim.uv.fs_symlink)(path, new_path, flags)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_readlink()
---
---@async
---@param path string
---@return string? err
---@return string? path
M.fs_readlink = function(path)
	return wrap(vim.uv.fs_readlink)(path)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_realpath()
---
---@async
---@param path string
---@return string? err
---@return string? path
M.fs_realpath = function(path)
	return wrap(vim.uv.fs_realpath)(path)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_chown()
---
---@async
---@param path string
---@param uid integer
---@param gid integer
---@return string? err
---@return boolean? success
M.fs_chown = function(path, uid, gid)
	return wrap(vim.uv.fs_chown)(path, uid, gid)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_fchown()
---
---@async
---@param fd integer
---@param uid integer
---@param gid integer
M.fs_fchown = function(fd, uid, gid)
	return wrap(vim.uv.fs_fchown)(fd, uid, gid)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_lchown()
---
---@async
---@param fd integer
---@param uid integer
---@param gid integer
M.fs_lchown = function(fd, uid, gid)
	return wrap(vim.uv.fs_lchown)(fd, uid, gid)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_copyfile()
---
---@async
---@param path string
---@param new_path string
---@param flags? table|integer
M.fs_copyfile = function(path, new_path, flags)
	return wrap(vim.uv.fs_copyfile)(path, new_path, flags)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_opendir()
---
---@async
---@param path string
---@param entries? integer
---@return string? err
---@return uv.luv_dir_t? dir
M.fs_opendir = function(path, entries)
	return wrap(vim.uv.fs_opendir, {
		cleanup = function(err, dir)
			if not err then
				vim.uv.fs_closedir(dir)
			end
		end,
	}, 2)(path, entries)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_readdir()
---
---@async
---@param dir uv.luv_dir_t
---@return string? err
---@return table? entries
M.fs_readdir = function(dir)
	return wrap(vim.uv.fs_readdir)(dir)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_closedir()
---
---@async
---@param dir uv.luv_dir_t
---@return string? err
---@return boolean? success
M.fs_closedir = function(dir)
	return wrap(vim.uv.fs_closedir)(dir)
end

--- https://neovim.io/doc/user/luvref.html#uv.fs_statfs()
---
---@async
---@param path string
---@return string? err
---@return table? statfs
M.fs_statfs = function(path)
	return wrap(vim.uv.fs_statfs)(path)
end

return M
