--- Busted tests for coop.task-utils.
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
		future:await()
		cb(f(...))
	end

	return cb_function, f_resume
end

describe("coop.task-utils", function()
	describe("cb_to_tf", function()
		it("converts an immediate callback-based function to a task function", function()
			local f = function(cb, a, b)
				cb(a + b)
			end
			local f_co_ret = coop.spawn(coop.cb_to_tf(f), 1, 2):await()
			assert.are.same(3, f_co_ret)
		end)

		it("works with an immediate callback-based function that returns multiple results", function()
			local f = function(cb, a, b)
				cb(a + b, a * b)
			end

			local f_co_ret_sum, f_co_ret_mul = coop.spawn(coop.cb_to_tf(f), 1, 2):await()

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
				f_co_ret = coop.cb_to_tf(f)(1, 2)
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
				f_co_ret_sum, f_co_ret_mul = coop.cb_to_tf(f)(1, 2)
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
				results = { coop.cb_to_tf(f)() }
			end)

			-- Simulate the callback being called asynchronously.
			f_resume()

			assert.are.same({ "foo", nil, "bar", nil }, results)
		end)
	end)
end)
