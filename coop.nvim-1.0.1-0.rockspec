rockspec_format = "3.0"
package = "coop.nvim"
version = "1.0.1-0"

source = {
	url = "git+https://github.com/gregorias/coop.nvim",
}

description = {
	summary = "A Neovim plugin for structured concurrency with coroutines.",
	homepage = "https://github.com/gregorias/coop.nvim", -- We don't have one yet
	license = "GPL-3.0",
}

dependencies = {
	"lua >= 5.1",
}

build = {
	type = "builtin",
	modules = {
		coop = "lua/coop.lua",
		["coop.control"] = "lua/coop/control.lua",
		["coop.coroutine-utils"] = "lua/coop/coroutine-utils.lua",
		["coop.examples"] = "lua/coop/examples.lua",
		["coop.functional-utils"] = "lua/coop/functional-utils.lua",
		["coop.future"] = "lua/coop/future.lua",
		["coop.lsp.client"] = "lua/coop/lsp/client.lua",
		["coop.mpsc-queue"] = "lua/coop/mpsc-queue.lua",
		["coop.subprocess"] = "lua/coop/subprocess.lua",
		["coop.table-utils"] = "lua/coop/table-utils.lua",
		["coop.task"] = "lua/coop/task.lua",
		["coop.task-utils"] = "lua/coop/task-utils.lua",
		["coop.uv"] = "lua/coop/uv.lua",
		["coop.uv-utils"] = "lua/coop/uv-utils.lua",
		["coop.vim"] = "lua/coop/vim.lua",
	},
}
