local M = {}
local coop = require("coop")
local copcall = require("coop.coroutine-utils").copcall
local await_any = require("coop.control").await_any
local as_completed = require("coop.control").as_completed
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
--- This is a good example of true parallelism enabled by this framework (each timer is working in parallel) and
--- `as_complete` for synchronization.
---
---@async
---@param values number[] the values to sort
---@return number[] sorted_values the sorted values
M.sort_with_time = function(values)
	local tasks = {}

	-- For each number, create a task that sleeps for that number of milliseconds.
	for i, value in ipairs(values) do
		tasks[i] = coop.spawn(function()
			uv.sleep(value)
			return value
		end)
	end

	local sorted_results = {}
	for t in as_completed(tasks) do
		sorted_results[#sorted_results + 1] = t()
	end

	return sorted_results
end

--- Runs a simulated parallel search.
---
--- This example shows cancellation and error handling.
---
---@async
---@return string result the result of the fast task
---@return string result the result of the slow task
M.run_parallel_search = function()
	local slow_tf = function()
		local success, err_msg = copcall(uv.sleep, 5000)
		if not success and err_msg == "cancelled" then
			return "cancelled"
		else
			return "slow"
		end
	end

	local fast_tf = function()
		local success, err_msg = copcall(uv.sleep, 30)
		if not success and err_msg == "cancelled" then
			return "cancelled"
		else
			return "fast"
		end
	end

	local slow_task, fast_task = coop.spawn(slow_tf), coop.spawn(fast_tf)
	local done_task, remaining_tasks = await_any({ slow_task, fast_task })
	for _, task in ipairs(remaining_tasks) do
		task:cancel()
	end

	return done_task(), remaining_tasks[1]()
end

return M
