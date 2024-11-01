--- This module provides fire-and-forget coroutine functions for Libuv.
local M = {}

local coop = require("coop")
local functional_utils = require("coop.functional-utils")
local shift_cb = functional_utils.shift_parameters

--- Wraps the callback param with `vim.schedule_wrap`.
---
--- This is useful for Libuv functions to ensure that their continuations can run `vim.api` functions without problems.
---
---@param f function
---@return function
local schedule_cb = function(f)
	return function(cb, ...)
		f(vim.schedule_wrap(cb), ...)
	end
end

local timer_start = coop.cb_to_co(schedule_cb(shift_cb(vim.uv.timer_start)))

--- Sleeps for a number of milliseconds.
---
--- This is a fire-and-forget coroutine function.
---
---@param ms number The number of milliseconds to sleep.
M.sleep = function(ms)
	local timer = vim.uv.new_timer()
	timer_start(timer, ms, 0)
	timer:stop()
	timer:close()
end

return M
