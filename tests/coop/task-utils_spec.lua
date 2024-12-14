--- Busted tests for coop.task-utils.
local coop = require("coop")
local task = require("coop.task")
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

local create_blocked_coroutine_function = function(f)
	local pass = false
	local thread = nil

	local coroutine_function = function(...)
		thread = task.running()
		if not pass then
			task.yield()
		end
		return f(...)
	end

	local f_resume = function()
		pass = true
		if thread then
			task.resume(thread)
		end
	end

	return coroutine_function, f_resume
end

describe("coop.task-utils", function()
	describe("cb_to_tf", function()
		local cb_to_tf = coop.cb_to_tf

		it("converts an immediate callback-based function to a task function", function()
			local f = function(cb, a, b)
				cb(a + b)
			end
			local f_tf_ret = coop.spawn(cb_to_tf(f), 1, 2):await()
			assert.are.same(3, f_tf_ret)
		end)

		it(
			"works with an immediate callback-based function that returns multiple results",
			function()
				local f = function(cb, a, b)
					cb(a + b, nil, a * b)
				end

				local f_tf_ret_sum, f_tf_nil, f_tf_ret_mul = coop.spawn(cb_to_tf(f), 1, 2):await()

				assert.are.same(3, f_tf_ret_sum)
				assert.is.Nil(f_tf_nil)
				assert.are.same(2, f_tf_ret_mul)
			end
		)

		it("works with a delayed callback-based function that returns multiple results", function()
			local f, f_resume = create_blocked_cb_function(function(a, b)
				return a + b, nil, a * b
			end)
			local f_tf_ret_sum, f_tf_nil, f_tf_ret_mul = nil, nil, nil

			-- Spawn the coroutine, which will call f and yield.
			coop.spawn(function()
				f_tf_ret_sum, f_tf_nil, f_tf_ret_mul = cb_to_tf(f)(1, 2)
			end)

			-- Simulate the callback being called asynchronously.
			f_resume()

			assert.are.same(3, f_tf_ret_sum)
			assert.is.Nil(f_tf_nil)
			assert.are.same(2, f_tf_ret_mul)
		end)

		it("runs cleanup function on cancel", function()
			local on_cancel_called, cleanup_called = false, false
			local f, f_resume = create_blocked_cb_function(function() end)

			local f_tf = cb_to_tf(f, {
				on_cancel = function()
					on_cancel_called = true
				end,
				cleanup = function()
					cleanup_called = true
				end,
			})

			local t = coop.spawn(f_tf)
			t:cancel()

			assert.has.error(function()
				t:await(10, 2)
			end, "cancelled")
			assert.is.True(on_cancel_called)
			assert.is.False(cleanup_called)

			f_resume()

			assert.is.True(on_cancel_called)
			assert.is.True(cleanup_called)
		end)

		it("cancels with a returned handle in on_cancel", function()
			local handle = {}
			-- `f` returns a handle to an ongoing op that `on_cancel` should “cancel.”
			local tf = cb_to_tf(function(_)
				handle = { status = "running" }
				return handle
			end, {
				on_cancel = function(_, f_ret)
					f_ret[1].status = "cancelled"
				end,
			})

			coop.spawn(tf):cancel()

			assert.are.same("cancelled", handle.status)
		end)
	end)

	describe("spawn", function()
		it("returns an awaitable future", function()
			local f, f_resume = create_blocked_coroutine_function(function()
				return 1, 2
			end)

			local f_future = coop.spawn(f)
			local f_ret_0, f_ret_1 = nil, nil
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
			local success = false
			local f_ret_0 = nil
			local f_ret_1 = nil

			f_future:await(function(success_, a, b)
				success, f_ret_0, f_ret_1 = success_, a, b
			end)

			f_resume()

			assert.is.True(success)
			assert.are.same({ 1, 2 }, { f_ret_0, f_ret_1 })
		end)

		it("spawned tasks capture errors", function()
			local f, f_resume = create_blocked_coroutine_function(function()
				error("foo", 0)
			end)

			local f_future = coop.spawn(f)
			local success = true
			local f_err = ""

			f_future:await(function(success_, err)
				success, f_err = success_, err
			end)

			f_resume()

			assert.is.False(success)
			assert.are.same("foo", f_err)
		end)
	end)

	describe("co_to_tf", function()
		local co_to_tf = require("coop.task-utils").co_to_tf

		it("converts a regular coroutine function to a task function", function()
			local f_co = function(a, b)
				local arg = coroutine.yield(a + b, nil, a * b)
				return arg + 1
			end

			local f_tf = co_to_tf(f_co)

			local t = task.create(f_tf)
			local success, f_ret_sum, f_ret_nil, f_ret_mul = t:resume(1, 2)

			assert.is.True(success)
			assert.are.same(3, f_ret_sum)
			assert.is.Nil(f_ret_nil)
			assert.are.same(2, f_ret_mul)

			local success_2, f_ret_inc = t:resume(4)

			assert.is.True(success_2)
			assert.are.same(5, f_ret_inc)

			assert.are.same("dead", t:status())
		end)

		it("forwards errors", function()
			local f_co = function()
				error("foo", 0)
			end

			local f_tf = co_to_tf(f_co)
			local t = task.create(f_tf)
			local success, err = t:resume()

			assert.is.False(success)
			assert.are.same("foo", err)
		end)

		it("result can be cancelled", function()
			local f_co = function()
				coroutine.yield()
			end
			local f_tf = co_to_tf(f_co)
			local t = task.create(f_tf)
			t:cancel()

			assert.are.same("dead", t:status())
			assert.is.True(t.cancelled)
		end)
	end)
end)
