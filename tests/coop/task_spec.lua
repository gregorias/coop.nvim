--- Busted tests for coop.task.
local coop = require("coop")
local task = require("coop.task")
local uv = require("coop.uv")

describe("coop.task", function()
	describe("cancel", function()
		it("cancelled task’s future returns an error and it never executes", function()
			local done = false
			local spawned_task = coop.spawn(function()
				uv.sleep(20)
				done = true
			end)

			-- Immediately cancel the task.
			task.cancel(spawned_task)

			-- Let the timer run out.
			vim.wait(40)

			assert.is.False(done)
			assert.are.same({ false, "The task was cancelled." }, { task.resume(spawned_task) })
			assert.are.same("dead", task.status(spawned_task))
		end)

		it("doesn’t do anything on finished tasks", function()
			local spawned_task = coop.spawn(function() end)

			task.cancel(spawned_task)

			assert.is.False(spawned_task.cancelled)
		end)

		it("throws an error if called within a running task", function()
			local success, err = true, ""

			coop.spawn(function()
				success, err = pcall(task.cancel, task.running())
			end)

			assert.is.False(success)
			assert.are.same("You cannot cancel the currently running task.", err)
		end)
	end)
end)
