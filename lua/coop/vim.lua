--- This module provides a task function version of vim.system.
local M = {}

cb_to_tf = require("coop.task-utils").cb_to_tf
shift_parameters = require("coop.functional-utils").shift_parameters

-- env: table<string,string> Set environment variables for the new process. Inherits the current environment with NVIM set to v:servername.
-- clear_env: (boolean) env defines the job environment exactly, instead of merging current environment.
-- stdin: (string|string[]|boolean) If true, then a pipe to stdin is opened and can be written to via the write() method to SystemObj. If string or string[] then will be written to stdin and closed. Defaults to false.
-- stdout: (boolean|function) Handle output from stdout. When passed as a function must have the signature fun(err: string, data: string). Defaults to true
-- stderr: (boolean|function) Handle output from stderr. When passed as a function must have the signature fun(err: string, data: string). Defaults to true.
-- text: (boolean) Handle stdout and stderr as text. Replaces \r\n with \n.
-- timeout: (integer) Run the command with a time limit. Upon timeout the process is sent the TERM signal (15) and the exit code is set to 124.
-- detach: (boolean) If true, spawn the child process in a detached state - this will make it a process group leader, and will effectively enable the child to keep running after the parent exits. Note that the child process will still keep the parent's event loop alive unless the parent process calls uv.unref() on the child's process handle.

---@class vim.SystemOpts
---@field cwd? string
---@field env? table<string,string>
---@field clear_env? boolean
---@field stdin? string|string[]|boolean
---@field stdout? boolean|function
---@field stderr? boolean|function
---@field text? boolean
---@field timeout? integer
---@field detach? boolean

---@class vim.SystemCompleted
---@field code integer
---@field signal integer
---@field stdout string
---@field stderr string

--- Runs a system command or throws an error if cmd cannot be run.
---
---@async
---@diagnostic disable-next-line: undefined-doc-param
---@param cmd string[] The command to execute.
---@diagnostic disable-next-line: undefined-doc-param
---@param opts? vim.SystemOpts
---@return vim.SystemCompleted out
M.system = cb_to_tf(shift_parameters(vim.system))

return M
