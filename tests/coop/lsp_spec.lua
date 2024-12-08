--- Busted tests for coop.table-utils.

describe("coop.lsp", function()
	local FakeLspServer = require("tests.fake_lsp_server").server
	local coop = require("coop")
	local coop_lsp = require("coop.lsp.client")

	describe("client.request", function()
		it("forwards a request and response", function()
			local fake_server = FakeLspServer({})
			fake_server.stub_request_method("textDocument/definition", function(_, callback)
				callback(nil, { result = nil })
			end)

			local client_id = vim.lsp.start({
				name = "fake LSP",
				cmd = function(dispatchers)
					return fake_server(dispatchers)
				end,
			})
			local lsp_client = vim.lsp.get_client_by_id(client_id)

			local t = coop.spawn(function()
				return coop_lsp.request(lsp_client, "textDocument/definition", nil)
			end)
			local err, result = t:await(10, 1)
			assert.are.same(nil, err)
			assert.are.same({ result = nil }, result)
		end)

		it("returns an error on failed request", function()
			local fake_server = FakeLspServer({})

			local client_id = vim.lsp.start({
				name = "fake LSP",
				cmd = function(dispatchers)
					return fake_server(dispatchers)
				end,
			})
			local lsp_client = vim.lsp.get_client_by_id(client_id)

			local t = coop.spawn(function()
				return coop_lsp.request(lsp_client, "does_not_exist", nil)
			end)
			local err = t:await(10, 1)
			assert.are.same("Could not send the request for does_not_exist.", err)
		end)

		it("cancels ongoing requests", function()
			local fake_server = FakeLspServer({})
			fake_server.stub_request_method("textDocument/definition", function(_, _)
				-- Never calls the callback.
			end)

			local cancel_params = nil
			fake_server.stub_notification_method("$/cancelRequest", function(params)
				cancel_params = params
			end)

			local client_id = vim.lsp.start({
				name = "fake LSP",
				cmd = function(dispatchers)
					return fake_server(dispatchers)
				end,
			})
			local lsp_client = vim.lsp.get_client_by_id(client_id)

			local t = coop.spawn(function()
				return coop_lsp.request(lsp_client, "textDocument/definition", nil)
			end)
			t:cancel()

			---@diagnostic disable-next-line: undefined-field
			assert.is.True(cancel_params ~= nil and cancel_params.id ~= nil)
		end)
	end)
end)
