local M = {}
local coop = require("coop")
local uv = require("coop.uv")

--- Gets the size of a file.
---
--- This is a task function.
---
---@async
---@param path string the path to the file
---@return boolean success
---@return number|string size_or_err
local get_file_size = function(path)
	local err, fd_or_err = uv.fs_open(path, "r", 0)
	if err then
		return err, fd_or_err
	end
	local fd = fd_or_err

	local err_fstat, stat_or_err = uv.fs_fstat(fd)
	uv.fs_close(fd)

	if err_fstat then
		return err_fstat, stat_or_err
	end

	return true, stat_or_err.size
end

--- Runs a nonblocking search for a README file and returns its size.
---
--- This is a task function.
---
---@async
---@return boolean success
---@return number|string size_or_err
M.search_for_readme = function()
	local opendir_err, dir_or_err = uv.fs_opendir(".", 200)
	if opendir_err then
		return false, dir_or_err
	end
	local dir = dir_or_err

	local readdir_err, entries_or_err = uv.fs_readdir(dir)
	uv.fs_closedir(dir)
	if readdir_err then
		return false, entries_or_err
	end
	local entries = entries_or_err

	for _, entry in ipairs(entries) do
		if entry.name == "README.md" then
			local file_size_err, file_size_or_err = get_file_size(entry.name)
			return file_size_err, file_size_or_err
		end
	end

	return false, "Could not find README.md."
end

--- Sorts a list of numbers by waiting for the time of each number.
---
--- This is a plain coroutine function.
---
--- This is a good example of true parallelism enabled by this framework (each timer is working in parallel) and
--- `await_all` for synchronization.
---
---@async
---@param values number[] the values to sort
---@return number[] sorted_values the sorted values
M.sort_with_time = function(values)
	local futures = {}
	local sorted_results = {}

	-- For each number, create a task that sleeps for that number of milliseconds.
	for _, value in ipairs(values) do
		local future = coop.spawn(function()
			uv.sleep(value)
			table.insert(sorted_results, value)
		end)
		table.insert(futures, future)
	end

	coop.await_all(futures)

	return sorted_results
end

return M
