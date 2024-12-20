--- This module provides a task function version of vim.system.
local M = {}

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
---@param cmd string[] The command to execute.
---@param opts? vim.SystemOpts
---@return vim.SystemCompleted out
M.system = function(cmd, opts)
	local cb_to_tf = require("coop.task-utils").cb_to_tf
	local shift_parameters = require("coop.functional-utils").shift_parameters

	return cb_to_tf(shift_parameters(vim.system))(cmd, opts)
end

return M
