--- Busted tests for coop.task.
local coop = require("coop")
local copcall = require("coop.coroutine-utils").copcall
local task = require("coop.task")
local uv = require("coop.uv")

describe("coop.task", function()
	describe("cancel", function()
		it("cancelled task’s future returns an error and it becomes dead", function()
			local done = false
			local spawned_task = coop.spawn(function()
				uv.sleep(20)
				done = true
			end)

			-- Immediately cancel the task.
			spawned_task:cancel()

			-- Let the timer run out.
			vim.wait(40)

			-- Test that the task didn’t finish.
			assert.is.False(done)
			assert.are.same("dead", spawned_task:status())
		end)

		it("can be captured in yield", function()
			local success, err_msg = true, ""
			local spawned_task = coop.spawn(function()
				success, err_msg = copcall(uv.sleep, 20)
				error(err_msg)
			end)

			-- Immediately cancel the task.
			spawned_task:cancel()

			assert.is.False(success)
			assert.are.same("cancelled", err_msg)
		end)

		it("can uncancelled by user", function()
			local spawned_task = coop.spawn(function()
				copcall(uv.sleep, 20)
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
	end)

	describe("yield", function()
		it("throws if used outside of a task", function()
			local t = task.create(function()
				task.yield()
			end)

			coroutine.resume(t.thread)
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

			t:cancel()
			local success, err_msg = t:resume()

			assert.is.False(success)
			assert.are.same("cancelled", err_msg)
		end)
	end)
end)
