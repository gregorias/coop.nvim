--- Busted tests for coop.
local coop = require("coop")

--- Creates a cb function that blocks until a resume function is called.
---
--- The cb function returns the result of f.
---
--- This function is useful to simulate asynchronicity in synchronous tests.
---
---@treturn function The cb function.
---@treturn function The resume function.
local create_blocked_cb_function = function(f)
	local future = coop.Future.new()

	local f_resume = function()
		future:complete()
	end

	local cb_function = function(cb, ...)
		future:wait()
		cb(f(...))
	end

	return cb_function, f_resume
end

local create_blocked_coroutine_function = function(f)
	local pass = false
	local thread = nil

	local coroutine_function = function(...)
		thread = coroutine.running()
		if not pass then
			coroutine.yield()
		end
		return f(...)
	end

	local f_resume = function()
		pass = true
		if thread then
			coroutine.resume(thread)
		end
	end

	return coroutine_function, f_resume
end

describe("coop", function()
	describe("cb_to_co", function()
		it("converts an immediate callback-based function to a coroutine function", function()
			local f = function(cb, a, b)
				cb(a + b)
			end
			local f_co_ret = coop.spawn(coop.cb_to_co(f), 1, 2):wait()
			assert.are.same(3, f_co_ret)
		end)

		it("works with an immediate callback-based function that returns multiple results", function()
			local f = function(cb, a, b)
				cb(a + b, a * b)
			end

			local f_co_ret_sum, f_co_ret_mul = coop.spawn(coop.cb_to_co(f), 1, 2):wait()

			assert.are.same(3, f_co_ret_sum)
			assert.are.same(2, f_co_ret_mul)
		end)

		it("converts a delayed callback-based function to a coroutine function", function()
			local f, f_resume = create_blocked_cb_function(function(a, b)
				return a + b
			end)
			local f_co_ret = nil

			-- Spawn the coroutine, which will call f and yield.
			coop.spawn(function()
				f_co_ret = coop.cb_to_co(f)(1, 2)
			end)

			-- Simulate the callback being called asynchronously.
			f_resume()

			assert.are.same(3, f_co_ret)
		end)

		it("works with a delayed callback-based function that returns multiple results", function()
			local f, f_resume = create_blocked_cb_function(function(a, b)
				return a + b, a * b
			end)
			local f_co_ret_sum, f_co_ret_mul = nil, nil

			-- Spawn the coroutine, which will call f and yield.
			coop.spawn(function()
				f_co_ret_sum, f_co_ret_mul = coop.cb_to_co(f)(1, 2)
			end)

			-- Simulate the callback being called asynchronously.
			f_resume()

			assert.are.same(3, f_co_ret_sum)
			assert.are.same(2, f_co_ret_mul)
		end)

		it("works with a delayed callback-based function that returns multiple results with nils", function()
			local f, f_resume = create_blocked_cb_function(function()
				return "foo", nil, "bar", nil
			end)
			local results = nil

			-- Spawn the coroutine, which will call f and yield.
			coop.spawn(function()
				results = { coop.cb_to_co(f)() }
			end)

			-- Simulate the callback being called asynchronously.
			f_resume()

			assert.are.same({ "foo", nil, "bar", nil }, results)
		end)
	end)

	describe("spawn", function()
		it("returns an awaitable future", function()
			local f, f_resume = create_blocked_coroutine_function(function()
				return 1, 2
			end)

			local f_future = coop.spawn(f)
			local f_ret_0 = nil
			local f_ret_1 = nil
			coop.spawn(function()
				f_ret_0, f_ret_1 = f_future()
			end)

			f_resume()

			assert.are.same({ 1, 2 }, { f_ret_0, f_ret_1 })
		end)

		it("the returned future can wait with a callbacks", function()
			local f, f_resume = create_blocked_coroutine_function(function()
				return 1, 2
			end)

			local f_future = coop.spawn(f)
			local f_ret_0 = nil
			local f_ret_1 = nil

			f_future:wait(function(a, b)
				f_ret_0, f_ret_1 = a, b
			end)

			f_resume()

			assert.are.same({ 1, 2 }, { f_ret_0, f_ret_1 })
		end)
	end)

	describe("Future", function()
		it("completed future’s wait calls the callback immediately", function()
			local future = coop.Future.new()
			future:complete(1, 2)

			local f_ret_0, f_ret_1 = nil, nil
			future:wait(function(...)
				f_ret_0, f_ret_1 = ...
			end)
			assert.are.same({ 1, 2 }, { f_ret_0, f_ret_1 })
		end)
	end)

	describe("await_all", function()
		it("works with immediately finished futures", function()
			local future = coop.Future.new()
			future:complete("foo")

			local results = nil
			coop.spawn(function()
				results = coop.await_all({ future })
			end)

			assert.are.same({ { "foo" } }, results)
		end)

		it("works with delayed futures", function()
			local future_1, future_2 = coop.Future.new(), coop.Future.new()

			local results = nil
			coop.spawn(function()
				results = coop.await_all({ future_1, future_2 })
			end)

			future_1:complete("foo")
			future_2:complete("bar")

			assert.are.same({ { "foo" } , { "bar" } }, results)
		end)
	end)
end)
