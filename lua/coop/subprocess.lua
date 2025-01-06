--- The module for running subprocesses.
local M = {}

M.PIPE = "pipe"
M.STREAM = "stream"

---@alias signum integer|string|nil

---@class Coop.Process
---@field handle uv.uv_process_t The handle to the process.
---@field pid integer The process ID.
---@field stdin uv.uv_pipe_t | Coop.StreamWriter The stdin of the process.
---@field stdout uv.uv_pipe_t | Coop.StreamReader The stdout of the process.
---@field stderr uv.uv_pipe_t | Coop.StreamReader The stderr of the process.
---
---@field await async function Waits for the process to finish.
---@field kill fun(self: Coop.Process, signal: signum) Kills the process. Returns 0 or fail.

---@class Coop.SpawnOptions
---@field args? table The arguments to pass to the process.
---@field stdio? table The stdio configuration for the process.
---                    Accepts either same values as vim.uv.spawn, or PIPE or STREAM.
---                    If PIPE is provided, a uv_pipe_t is provided in the returned process object.
---                    If STREAM is provided, a StreamReader/Writer is provided in the returned process object.
---@field env? table The environment variables for the process.
---@field cwd? string The current working directory for the process.
---@field uid? integer The user id for the process.
---@field gid? integer The group id for the process.
---@field verbatim? boolean If true, do not wrap any arguments in quotes, or perform any other escaping, when converting
---                         the argument list into a command line string. This option is only meaningful on Windows
---                         systems. On Unix it is silently ignored.
---@field detached? boolean Whether the process should be detached.
---@field hide? boolean Whether the process should be hidden.

--- Spawns a subprocess.
---
--- Uses `vim.uv.spawn` under the hood.
---
---@param cmd string The command to run.
---@param opts Coop.SpawnOptions
---@return Coop.Process process The process object.
M.spawn = function(cmd, opts)
	local uv = require("coop.uv")
	local table_utils = require("coop.table-utils")

	opts.stdio = opts.stdio or {}
	local uv_stdio = table_utils.shallow_copy(opts.stdio)
	local process_stdin = nil
	local process_stdout = nil
	local process_stderr = nil

	if opts.stdio[1] == M.PIPE or opts.stdio[1] == M.STREAM then
		uv_stdio[1] = vim.uv.new_pipe()
		process_stdin = uv_stdio[1]
	end
	if opts.stdio[2] == M.PIPE or opts.stdio[2] == M.STREAM then
		uv_stdio[2] = vim.uv.new_pipe()
		process_stdout = uv_stdio[2]
	end
	if uv_stdio[3] == M.PIPE or opts.stdio[3] == M.STREAM then
		uv_stdio[3] = vim.uv.new_pipe()
		process_stderr = uv_stdio[3]
	end

	local uv_opts = {
		args = opts.args,
		stdio = uv_stdio,
		env = opts.env,
		cwd = opts.cwd,
		uid = opts.uid,
		gid = opts.gid,
		verbatim = opts.verbatim,
		detached = opts.detached,
		hide = opts.hide,
	}

	local process_handle, pid, process_future = uv.spawn(cmd, uv_opts)

	local StreamReader = require("coop.uv-utils").StreamReader
	local StreamWriter = require("coop.uv-utils").StreamWriter

	if opts.stdio[1] == M.STREAM and process_stdin ~= nil then
		process_stdin = StreamWriter.new(process_stdin)
	end
	if opts.stdio[2] == M.STREAM and process_stdout ~= nil then
		process_stdout = StreamReader.new(process_stdout)
	end
	if opts.stdio[3] == M.STREAM and process_stderr ~= nil then
		process_stderr = StreamReader.new(process_stderr)
	end

	return {
		handle = process_handle,
		pid = pid,
		stdin = process_stdin,
		stdout = process_stdout,
		stderr = process_stderr,
		await = function(_, ...)
			return process_future:await(...)
		end,
		kill = function(self, signal)
			return vim.uv.process_kill(self.handle, signal)
		end,
	}
end

return M
