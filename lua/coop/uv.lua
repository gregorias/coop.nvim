--- This module provides fire-and-forget coroutine functions for Libuv.
local M = {}

local coop = require("coop")
local functional_utils = require("coop.functional-utils")
local shift_cb = functional_utils.shift_parameters

local timer_start = coop.cb_to_co(shift_cb(vim.uv.timer_start))

--- Sleeps for a number of milliseconds.
---
--- This is a fire-and-forget coroutine function.
M.sleep = function(ms)
	local timer = vim.uv.new_timer()
	timer_start(timer, ms, 0)
	timer:stop()
	timer:close()
end

return M
