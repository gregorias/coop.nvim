--- Busted tests for coop.coroutine-utils.
local coop = require("coop")
local sleep = require("coop.uv-utils").sleep
local coroutine_utils = require("coop.coroutine-utils")
local copcall = coroutine_utils.copcall
local pack = require("coop.table-utils").pack

--- Creates a cb function that blocks until a resume function is called.
---
--- The cb function returns the result of f.
---
--- This function is useful to simulate asynchronicity in synchronous tests.
---
---@return function cb_function cb function
---@return function f_resume The resume function.
local create_blocked_cb_function = function(f)
	local cb = function() end

	local f_resume = function()
		cb()
	end

	local cb_function = function(cb_, ...)
		local args = pack(...)
		cb = function()
			cb_(f(unpack(args, 1, args.n)))
		end
	end

	return cb_function, f_resume
end

describe("coop.coroutine-utils", function()
	describe("cb_to_co", function()
		local cb_to_co = coroutine_utils.cb_to_co
		local spawn = function(f_co, ...)
			return coroutine.resume(coroutine.create(f_co), ...)
		end

		it("converts an immediate callback-based function to a coroutine function", function()
			local f = function(cb, a, b)
				cb(a + b)
			end
			local _, f_co_ret = spawn(cb_to_co(f), 1, 2)
			assert.are.same(3, f_co_ret)
		end)

		it(
			"works with an immediate callback-based function that returns multiple results",
			function()
				local f = function(cb, a, b)
					cb(a + b, nil, a * b)
				end

				local _, f_co_ret_sum, f_co_nil, f_co_ret_mul = spawn(cb_to_co(f), 1, 2)

				assert.are.same(3, f_co_ret_sum)
				assert.is.Nil(f_co_nil)
				assert.are.same(2, f_co_ret_mul)
			end
		)

		it("works with a delayed callback-based function that returns multiple results", function()
			local f, f_resume = create_blocked_cb_function(function(a, b)
				return a + b, nil, a * b
			end)
			local f_co_ret_sum, f_tf_nil, f_co_ret_mul = nil, nil, nil

			-- Spawn the coroutine, which will call f and yield.
			spawn(function()
				f_co_ret_sum, f_tf_nil, f_co_ret_mul = cb_to_co(f)(1, 2)
			end)

			-- Simulate the callback being called asynchronously.
			f_resume()

			assert.are.same(3, f_co_ret_sum)
			assert.is.Nil(f_tf_nil)
			assert.are.same(2, f_co_ret_mul)
		end)
	end)

	describe("copcall", function()
		it("executes a throwing coroutine function in a protected mode", function()
			local throw_after_sleep = function()
				sleep(2)
				error("error", 0)
			end
			local f_co = function()
				return copcall(throw_after_sleep)
			end

			local success, err_msg = coop.spawn(f_co):await(5, 1)

			assert.is.False(success)
			assert.are.same("error", err_msg)
		end)

		it("executes a successful coroutine function in a protected mode", function()
			local throw_after_sleep = function()
				sleep(2)
				return "foo", nil, "bar"
			end
			local f_co = function()
				return copcall(throw_after_sleep)
			end

			local success, val_foo, val_nil, val_bar = coop.spawn(f_co):await(5, 1)

			assert.is.True(success)
			assert.are.same("foo", val_foo)
			assert.is.Nil(val_nil)
			assert.are.same("bar", val_bar)
		end)
	end)

	describe("fire_and_forget", function()
		it("runs the coroutine function", function()
			local first_stage = false
			local second_stage = false
			coroutine_utils.fire_and_forget(function()
				first_stage = true
				coroutine.yield()
				second_stage = true
			end)

			assert.is.True(first_stage)
			assert.is.False(second_stage)
		end)
	end)
end)
