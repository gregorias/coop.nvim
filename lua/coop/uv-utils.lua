--- Utilities for working with libuv.
---
--- sleep: Sleeps for a number of milliseconds.
--- StreamReader: An async wrapper for a readable uv_stream_t.
--- StreamWriter: An async wrapper for a writable uv_stream_t.
local M = {}

--- Sleeps for a number of milliseconds.
---
---@async
---@param ms number The number of milliseconds to sleep.
M.sleep = function(ms)
	local uv = require("coop.uv")
	local copcall = require("coop.coroutine-utils").copcall

	local timer = vim.uv.new_timer()
	local success, err = copcall(uv.timer_start, timer, ms, 0)
	-- Safely close resources even in case of a cancellation error.
	timer:stop()
	timer:close()
	if not success then
		error(err, 0)
	end
end

--- A stream reader is an async wrapper for a readable uv_stream_t.
---
--- This is useful for a subprocess’s stdout and stderr..
---
---@class StreamReader
---@field handle uv_stream_t
---@field buffer MpscQueue
---@field at_eof boolean
---@field read async fun(StreamReader): string?
---@field read_until_eof async fun(StreamReader): string
---@field close async fun(StreamReader)

M.StreamReader = {}

--- Creates a stream reader.
---
---@param handle uv_stream_t The handle to a readable stream.
---@return StreamReader stream_reader The stream writer object.
M.StreamReader.new = function(handle)
	if not vim.uv.is_readable(handle) then
		error("Can not create a stream reader, because the handle is not readable.")
	end
	local MpscQueue = require("coop.mpsc-queue").MpscQueue

	local stream_reader = { handle = handle, buffer = MpscQueue.new(), at_eof = false }

	vim.uv.read_start(handle, function(err, data)
		if not err then
			stream_reader.buffer:push(data)
		end
	end)

	return setmetatable(stream_reader, { __index = M.StreamReader })
end

--- Creates a stream reader from a file descriptor.
---
---@param fd integer The file descriptor.
---@return StreamReader stream_reader The stream reader object.
M.StreamReader.from_fd = function(fd)
	local handle = vim.uv.new_pipe()
	handle:open(fd)
	return M.StreamReader.new(handle)
end

--- Reads data from the stream.
---
---@async
---@param self StreamReader
---@return string? data The data read from the stream or nil if the stream is at EOF.
M.StreamReader.read = function(self)
	if self.at_eof then
		return nil
	end

	local data = self.buffer:pop()
	if data == nil then
		self.at_eof = true
	end

	return data
end

--- Reads remaining data from the stream.
---
---@async
---@param self StreamReader
---@return string data The data read from the stream.
M.StreamReader.read_until_eof = function(self)
	local data = {}

	local chunk = self:read()
	local i = 1
	while chunk ~= nil do
		data[i] = chunk
		i = i + 1
		chunk = self:read()
	end

	return table.concat(data, "")
end

--- Closes the stream reader.
---
---@async
---@param self StreamReader
M.StreamReader.close = function(self)
	return require("coop.uv").close(self.handle)
end

--- A stream writer is an async wrapper for a writable uv_stream_t.
---
--- This is useful for a subprocess’s stdin.
---
---@class StreamWriter
---@field handle uv_stream_t
---@field write async fun(StreamWriter, string)
---@field close async fun(StreamWriter)

M.StreamWriter = {}

--- Creates a stream writer.
---
---@param handle uv_stream_t The handle to a writable stream.
---@return StreamWriter stream_writer The stream writer object.
M.StreamWriter.new = function(handle)
	if not vim.uv.is_writable(handle) then
		error("Can not create a stream writer, because the handle is not writable.")
	end

	local stream_writer = { handle = handle }
	local meta_stream_writer = {
		__index = M.StreamWriter,
	}
	return setmetatable(stream_writer, meta_stream_writer)
end

--- Creates a stream writer from a file descriptor.
---
---@param fd integer The file descriptor.
---@return StreamWriter stream_writer The stream writer object.
M.StreamWriter.from_fd = function(fd)
	local handle = vim.uv.new_pipe()
	handle:open(fd)
	return M.StreamWriter.new(handle)
end

--- Writes data to the stream.
---
---@async
---@param self StreamWriter
---@param data string The data to write.
---@return string? err
---@return string? err_name
M.StreamWriter.write = function(self, data)
	return require("coop.uv").write(self.handle, data)
end

--- Closes the stream writer.
---
---@async
---@param self StreamWriter
M.StreamWriter.close = function(self)
	return require("coop.uv").close(self.handle)
end

return M
