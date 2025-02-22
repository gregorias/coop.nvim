--- Task functions for LSP.
local M = {}

--- Sends a request to the connected LSP server.
---
--- https://neovim.io/doc/user/lsp.html#Client%3Arequest()
---
---@async
---@param client vim.lsp.Client
---@param method string
---@param params? table
---@param bufnr? integer
---@return string|table? err Error info dict, string, or nil if the request completed.
---@return any? result `result` key of the LSP response or nil if the request failed.
---@return lsp.HandlerContext? ctx The context of the request.
function M.request(client, method, params, bufnr)
	local request_cb = function(cb)
		local success, request_id = client.request(method, params, function(...)
			cb(...)
		end, bufnr)
		if not success then
			cb("Could not send the request for " .. method .. ".")
		end
		return success, request_id
	end

	local task_utils = require("coop.task-utils")

	return task_utils.cb_to_tf(request_cb, {
		on_cancel = function(_, rvals)
			local unpack_packed = require("coop.table-utils").unpack_packed
			local success, request_id = unpack_packed(rvals)
			if success and request_id then
				client.cancel_request(request_id)
			end
		end,
	})()
end

return M
