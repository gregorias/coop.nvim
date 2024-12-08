--- A fake LSP server that can be used to test LSP-related functionality.
local M = {}

---@alias Coop.vim.lsp.rpc.Dispatchers table

--- Returns an LSP server implementation.
---
---@param dispatchers Coop.vim.lsp.rpc.Dispatchers Methods that allow the server to interact with the client.
---@return table srv The server object.
function M.server(dispatchers)
	local closing = false
	local srv = {}
	local mt = {}
	local request_handlers = {}
	local notification_handlers = {}
	local request_id = 0

	-- With this call, it’s possible to interact with the server, e.g., set up new handlers.
	mt.__call = function(_, new_dispatchers)
		dispatchers = new_dispatchers
		return srv
	end
	setmetatable(srv, mt)

	--- This method is called each time the client makes a request to the server
	---
	--- To learn more about what method names are available and the structure of
	--- the payloads, read the specification:
	--- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/.
	---
	---@param method string the LSP method name
	---@param params table the payload that the LSP client sends
	---@param callback function A function which takes two parameters: `err` and `result`.
	---                         The callback must be called to send a response to the client.
	---@return boolean success
	---@return number? request_id
	function srv.request(method, params, callback)
		if method == "initialize" then
			callback(nil, { capabilities = {} })
		elseif method == "shutdown" then
			callback(nil, nil)
		elseif request_handlers[method] ~= nil then
			request_handlers[method](params, callback)
		else
			return false, nil
		end
		request_id = request_id + 1
		return true, request_id
	end

	--- This method is called each time the client sends a notification to the server
	--- The difference between `request` and `notify` is that notifications don’t
	--- expect a response.
	---
	---@param method string the LSP method name
	---@param params table the payload that the LSP client sends
	function srv.notify(method, params)
		if method == "exit" then
			dispatchers.on_exit(0, 15)
		elseif notification_handlers[method] ~= nil then
			notification_handlers[method](params)
		end
	end

	--- Indicates if the client is shutting down
	---
	---@return boolean
	function srv.is_closing()
		return closing
	end

	--- Called when the client wants to terminate the process
	function srv.terminate()
		closing = true
	end

	function srv.stub_request_method(method, callback)
		request_handlers[method] = callback
	end

	function srv.stub_notification_method(method, callback)
		notification_handlers[method] = callback
	end

	return srv
end

return M
