--- Busted tests for coop.control
local coop = require("coop")
local task = require("coop.task")
local spawn = coop.spawn
local copcall = coop.copcall
local control = require("coop.control")
local sleep = require("coop.uv-utils").sleep

describe("coop.control", function()
	describe("gather", function()
		it("works with empty input", function()
			assert.are.same({}, coop.spawn(control.gather, {}):await(100, 1))
		end)

		it("works with multiple results", function()
			local t = coop.spawn(function()
				return true, "foo"
			end)

			local gather_t = coop.spawn(control.gather, { t })
			local results = gather_t:await(100, 1)
			assert.are.same({ { true, "foo" } }, results)
		end)

		it("cancel cancels subtasks and returns cancellation error", function()
			local sleep_t = coop.spawn(sleep, 100)

			local gather_t = coop.spawn(control.gather, { sleep_t })
			gather_t:cancel()

			assert.is.True(gather_t:is_cancelled())
			assert.is.True(sleep_t:is_cancelled())
		end)

		it("error from a subtask makes gather throw", function()
			local sleep_t = coop.spawn(sleep, 200)
			local result_t = coop.spawn(function()
				sleep(10)
				error("foo")
			end)

			local gather_t = coop.spawn(control.gather, { sleep_t, result_t })

			assert.has.error(function()
				gather_t:await(100, 1)
			end, "foo")
		end)
	end)

	describe("shield", function()
		local shield = control.shield
		it("throws outside task", function()
			assert.has.error(function()
				shield(function() end)
			end, "shield can only be used in a task.")
		end)

		it("executes wrapped function", function()
			local t = spawn(function()
				return shield(function()
					return "foo"
				end)
			end)
			assert.are.same("foo", t:await(10, 1))
		end)

		it("rethrows errors from wrapped function", function()
			local t = spawn(function()
				shield(function()
					error("foo")
				end)
			end)

			assert.has.error(function()
				t:await(10, 1)
			end, "foo")
		end)

		it("protects from cancellation but still throws", function()
			---@type Task
			local internal_task = nil
			local internal_task_done = false
			local t = spawn(function()
				shield(function()
					---@diagnostic disable-next-line: cast-local-type
					internal_task = task.running()
					-- Yield and wait for resuming.
					task.yield()
					internal_task_done = true
				end)
			end)
			t:cancel()
			assert.is.False(internal_task_done)

			internal_task:resume()
			assert.is.True(internal_task_done)

			assert.has.error(function()
				t:await(100, 1)
			end, "cancelled")
		end)

		it("completely ignores cancellation with copcall", function()
			---@type Task
			local internal_task = nil
			local internal_task_done = false
			local t = spawn(function()
				local success, result = copcall(shield, function()
					---@diagnostic disable-next-line: cast-local-type
					internal_task = task.running()
					-- Yield and wait for resuming.
					task.yield()
					internal_task_done = true
				end)
				assert.is.False(success)
				assert.are.same({ false, "cancelled" }, { success, result })

				assert.is.True(task.running():is_cancelled())
				task.running():unset_cancelled()
				return "foo"
			end)
			t:cancel()
			assert.is.False(internal_task_done)

			internal_task:resume()
			assert.is.True(internal_task_done)

			assert.are.same("foo", t:await(100, 1))
		end)
	end)

	describe("timeout", function()
		local timeout = control.timeout

		it("works normally with a task that finishes in time", function()
			local t = spawn(function()
				return timeout(100, function()
					return "foo", "bar"
				end)
			end)
			assert.are.same({ "foo", "bar" }, { t:await(100, 1) })
		end)

		it("rethrows errors from wrapped function", function()
			local t = spawn(function()
				timeout(100, function()
					error("foo")
				end)
			end)

			assert.has.error(function()
				t:await(10, 1)
			end, "foo")
		end)

		it("cancels overrunning task functions", function()
			local got_cancelled = false
			local t = spawn(function()
				return timeout(5, function()
					local _, err = copcall(sleep, 10)
					got_cancelled = err == "cancelled"
					error(err)
				end)
			end)

			assert.has.error(function()
				t:await(100, 1)
			end, "timeout")

			assert.is.True(got_cancelled)
		end)

		it("cancels subtask on cancellation", function()
			local got_cancelled = false
			local t = spawn(function()
				return timeout(1000, function()
					local _, err = copcall(sleep, 2000)
					got_cancelled = err == "cancelled"
					error(err)
				end)
			end)
			local success, results = t:cancel()

			assert.are.same({ false, "cancelled" }, { success, results })
			assert.is.True(got_cancelled)
		end)
	end)

	describe("await_any", function()
		it("throws on empty list", function()
			assert.has.error(function()
				control.await_any({})
			end, "The list of awaitables is empty.")
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

		it("returns immediately on receiving an empty list", function()
			local result = coop.spawn(function()
				return coop.await_all({})
			end):await()

			assert.are.same({}, result)
		end)

		it("throws if done outside a task", function()
			assert.has.error(function()
				coop.await_all({ coop.Future.new() })
			end, "await_all can only be used in a task.")
		end)
	end)
end)
