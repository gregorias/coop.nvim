--- Busted tests for coop.task.
local coop = require("coop")
local sleep = require("coop.uv-utils").sleep
local copcall = require("coop.coroutine-utils").copcall
local task = require("coop.task")

describe("coop.task", function()
	describe("cancel", function()
		it("cancelled task’s future returns an error and the task becomes dead", function()
			local done = false
			local spawned_task = coop.spawn(function()
				sleep(20)
				done = true
			end)

			-- Immediately cancel the task.
			spawned_task:cancel()

			spawned_task:await(function(success, result)
				assert.are.same("dead", spawned_task:status())
				assert.is.False(success)
				assert.are.same("cancelled", result)
			end)

			-- Wait to see if the task sets the done flag. It shouldn’t.
			vim.wait(40)

			-- Test that the task didn’t finish.
			assert.is.False(done)
			assert.is.True(spawned_task:is_cancelled())
			assert.are.same("dead", spawned_task:status())
		end)

		it("can be captured in yield", function()
			local success, err_msg = true, ""
			local spawned_task = coop.spawn(function()
				success, err_msg = copcall(sleep, 20)
				error(err_msg)
			end)

			-- Immediately cancel the task.
			spawned_task:cancel()

			assert.is.False(success)
			assert.are.same("cancelled", err_msg)
		end)

		it("can be uncancelled by user", function()
			local spawned_task = coop.spawn(function()
				local success = copcall(sleep, 20)
				if not success and task.running():is_cancelled() then
					task.running():unset_cancelled()
				end
				return "done"
			end)

			-- Immediately cancel the task.
			spawned_task:cancel()

			local result = spawned_task:await(50, 10)

			assert.is.False(spawned_task.cancelled)
			assert.are.same("done", result)
		end)

		it("doesn’t do anything on finished tasks", function()
			local spawned_task = coop.spawn(function() end)
			spawned_task:cancel()
			assert.is.False(spawned_task.cancelled)
		end)

		it("causes yield to throw an error after interception", function()
			local t = coop.spawn(function()
				local running, err_msg = task.pyield()
				assert.is.False(running)
				assert.are.same("cancelled", err_msg)

				local _, msg = pcall(task.pyield)
				return msg
			end)
			local success, result = t:cancel()
			assert.is.True(success)
			assert.are.same(
				"Called pyield inside a cancelled task."
					.. " If you want to intercept cancellation,"
					.. " you need to clear the cancellation flag with unset_cancelled.",
				result
			)
		end)

		it("throws an error if called within a running task", function()
			local success, err = true, ""

			coop.spawn(function()
				---@diagnostic disable-next-line: cast-local-type
				success, err = pcall(task.cancel, task.running())
			end)

			assert.is.False(success)
			assert.are.same("You cannot cancel the currently running task.", err)
		end)
	end)

	describe("resume", function()
		it("throws an error on dead tasks", function()
			local spawned_task = coop.spawn(function() end)
			local success, err_msg = pcall(task.resume, spawned_task)

			assert.is.False(success)
			assert.are.same("Tried to resume a task that is not suspended but dead.", err_msg)
		end)

		it("captures the final return value (coroutine)", function()
			local t = coroutine.create(function()
				return "foo"
			end)
			local success, foo = coroutine.resume(t)

			assert.is.True(success)
			assert.are.same("foo", foo)
		end)

		it("captures the final return value", function()
			local t = task.create(function()
				return "foo"
			end)
			local success, foo = t:resume()

			assert.is.True(success)
			assert.are.same("foo", foo)
		end)
	end)

	describe("yield", function()
		it("throws if used outside of a task", function()
			local t = task.create(function()
				task.yield()
			end)

			local success, err_msg = coroutine.resume(t.thread)

			assert.is.False(success)
			assert.are.same(
				"Called pyield outside of a running task. Make sure that you use yield in tasks.",
				err_msg
			)
		end)

		it("throws if resumed outside of a task", function()
			local t = task.create(function()
				task.yield()
			end)

			task.resume(t)
			local success, err_msg = coroutine.resume(t.thread)

			assert.is.False(success)
			assert.are.same(
				"coroutine.yield returned without a running task. Make sure that you use task.resume to resume tasks.",
				err_msg
			)
		end)

		it("throws if cancelled", function()
			local t = task.create(function()
				task.yield()
			end)

			t:resume()
			local success, err_msg = t:cancel()

			assert.is.False(success)
			assert.are.same("cancelled", err_msg)
		end)
	end)

	describe("pawait", function()
		it("returns errors", function ()
			local sub_t = coop.spawn(function ()
				sleep(5)
				error("foo", 0)
			end)
			local main_t = coop.spawn(function ()
				return sub_t:pawait()
			end)

			local success, err_msg = main_t:await(20, 1)

			assert.is.False(success)
			assert.are.same("foo", err_msg)
		end)
	end)
end)
