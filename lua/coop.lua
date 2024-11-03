--- The main module containing for Coop’s utility functions.
local M = {}

M.task = require("coop.task")
M.Future = require("coop.future").Future
M.cb_to_tf = require("coop.task-utils").cb_to_tf
M.spawn = require("coop.task-utils").spawn

-- Control utilities.
local control = require("coop.control")
M.await_any = control.await_any
M.await_all = control.await_all
M.as_completed = control.as_completed

return M
