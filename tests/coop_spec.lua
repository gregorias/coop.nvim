--- Busted tests for coop.
local coop = require("coop")
local task = require("coop.task")

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

describe("coop", function()
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

	describe("await_all", function()
		it("works with immediately finished futures", function()
			local future = coop.Future.new()
			future:complete("foo")

			local results = nil
			coop.spawn(function()
				results = coop.await_all({ future })
			end)

			assert.are.same({ { true, "foo" } }, results)
		end)

		it("works with delayed futures", function()
			local future_1, future_2 = coop.Future.new(), coop.Future.new()

			local results = nil
			coop.spawn(function()
				results = coop.await_all({ future_1, future_2 })
			end)

			future_1:complete("foo")
			future_2:complete("bar")

			assert.are.same({ { true, "foo" }, { true, "bar" } }, results)
		end)
	end)
end)
