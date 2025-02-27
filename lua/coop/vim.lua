--- This module provides a task function version of vim.system.
local M = {}

--- Runs a system command or throws an error if cmd cannot be run.
---
---@async
---@param cmd string[] The command to execute.
---@param opts? vim.SystemOpts
---@return vim.SystemCompleted out
M.system = function(cmd, opts)
	local cb_to_tf = require("coop.task-utils").cb_to_tf

	return cb_to_tf(function(cb)
		vim.system(cmd, opts, vim.schedule_wrap(cb))
	end)()
end

return M
