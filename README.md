<!-- markdownlint-disable MD013 MD033 MD041 -->

<div align="center">
  <p>
    <img src="assets/coop-name.png" align="center" alt="Coop Logo"
         width="400" />
  </p>
  <p>
    Straightforward Neovim asynchronicity with native Lua coroutines.
  </p>
</div>

Coop is a Neovim plugin that provides an asynchronous **op**eration framework
based on native Lua **co**routines.
If you write Lua code in Neovim, Coop lets you write non-blocking code that
looks synchronous.
It’s like async/await in some other languages.

Coop was designed to

- Be simple. [Coop should be easy to explain.](How%20it%20works.md)
- Stay close to native Lua coroutines and Lua’s idioms.
- Come with batteries included for Neovim.

Here’s what else you can expect from Coop:

- True parallelism with a rich set of control operators.
- A flexible cancellation mechanism.
- Extensibility — You can turn any callback-based function into a task
  function. If the callback-based function is non-blocking, so will the task
  function be.

> [!WARNING]
> Coop.nvim is right now in a preview release.
>
> - The interfaces should be mostly stable.
> - Some ports of standard library functions are missing.
> - Additional control function are missing.
>
> I want to see if there’s any initial reception before I commit fully to
> implementing all batteries.

## ⚡️ Requirements

- Neovim 0.10+

## 📦 Installation

Install the plugin with your preferred package manager, such as [Lazy]:

```lua
{
  "gregorias/coop.nvim",
}
```

## 🚀 Usage

### Examples tutorial

A good introduction to Coop is to look at code examples.
Check out [`lua/coop/examples.lua`](/lua/coop/examples.lua):

[`search_for_readme`](https://github.com/gregorias/coop.nvim/blob/0e2082500707f2a143ff924ad36577c348148517/lua/coop/examples.lua#L40)
shows a hello world of asynchronicity: filesystem operations.
Although `search_for_readme` is non-blocking, it looks _exactly_
like its synchronous counterpart would look like.
One tiny caveat is that you need to spawn it in your main, synchronous thread
with `coop.spawn(search_for_readme)`.

[`sort_with_time`](https://github.com/gregorias/coop.nvim/blob/0e2082500707f2a143ff924ad36577c348148517/lua/coop/examples.lua#L72)
shows that Coop achieves true parallelism.
It launches parallel timers with `coop.spawn` and uses a
`coop.control.as_completed` to conveniently capture results as each timer
completes.

[`run_parallel_search`](https://github.com/gregorias/coop.nvim/blob/0e2082500707f2a143ff924ad36577c348148517/lua/coop/examples.lua#L98)
is the final example. It shows the flexible cancellation mechanism together
with error handling through `copcall`.

### Interface guide

This section introduces the essential interfaces.

#### Task

The main abstraction of Coop is a **task**.
A **task** is an extension of a Lua coroutine with three capabilities:

- Holding results (including errors)
- Awaiting
- Cancellation

A task behaves like a coroutine and comes with its own equivalent functions that behave analogously:

```lua
task.create
task.resume

--- Yield throws `error("cancelled")` if in a cancelled task.
task.yield

task.status
task.running
```

There’s also `pyield` variant of `yield` that returns `success, results`
instead of throwing an error.

`task.create` accepts **task functions**, which is a function that may call `task.yield`.

Tasks come with two additional functions. A cancel function (which is also a method):

```lua
--- Cancels the task.
---
--- The cancelled task will throw `error("cancelled")` in its yield.
---
---@param task Task the task to cancel
function task.cancel(task)
  -- …
end
```

And an await method that has three variants:

```lua
-- Awaits task completion.
function task.await(task, cb_or_timeout, interval)
end

-- task.await() is a task function that waits for the task finish and return a result
result = task.await()

-- task.await(cb) is a callback-based function that calls the callback once the task is finished.
-- It doesn’t wait for the task.
task.await(function(success, result) end)

-- task.await(timeout, interval) is a blocking function that uses vim.wait to implement a busy-waiting loop.
task.await(1000, 100) -- Wait for 1s for the task to finish. Check every 100ms
```

Tasks implement a call operator that calls `await`. This allows for a fluent interface where tasks appear as
if they were regular task functions:

```lua
local get_result_1 = coop.spawn(compute, 100)
local get_result_2 = coop.spawn(compute, 200)
local result = get_result_1()
```

The essential task-related functions live in `coop.task` and `coop.task-utils` modules.

### Library reference

#### `coop.mpsc-queue`

`mpsc-queue` module provides a multiple-producer single-consumer concurrent
queue with an asynchronous `pop` method.

<details>

<summary>Code example</summary>

```lua
local MpscQueue = require('coop.mpsc_queue').MpscQueue
local q = MpscQueue.new()

-- Asynchronously print whatever is provided to q.
coop.spawn(function()
  while true do
    vim.print("Read: " .. q:pop())
  end
end)

-- Start two threads that will asynchronously get strings from two sources.
coop.spawn(function()
  while true do
    q:push(read_string_from_user())
  end
end)

coop.spawn(function()
  while true do
    q:push(read_string_from_something_else())
  end
end)
```

</details>

### FAQ

#### How do I block until an asynchronous function is done in synchronous code?

Asynchronous code doesn’t mix with synchronous functions.
If you need to wait in your synchronous code until an asynchronous task is
done, Coop implements a busy-waiting mechanism based on `vim.wait`:

```lua
--- This is a synchronous function.
function main()
  local task = coop.spawn(...)
  -- Wait for 5 seconds and poll every 20 milliseconds.
  return task:await(5000, 20)
end
```

## ✅ Comparison to similar tools

### Nio

Overall, [Nio] seems like a solid asynchronous framework.

I started Coop before I knew about Nio, and I continued building Coop, because
I thought I could make a design and implementation that are clearer and more
principled.
The litmus test for me was whether I would be able to write [a guide](How%20it%20works.md) into the
internals that is easy to follow for someone that knows coroutines.

In terms of features, Coop has a more powerful cancellation mechanism.
In Coop, task cancellation causes an error to be thrown in the affected task.
This allows the programmer to implement any custom cancellation logic, e.g., cancelling child tasks or unloading resources.
As far as I can tell, **Nio doesn’t let you safely unload resources upon cancellation** as
[it just makes the task dead](https://github.com/nvim-neotest/nvim-nio/blob/a428f309119086dc78dd4b19306d2d67be884eee/lua/nio/tasks.lua#L113-L116).

### Plenary Async

Plenary async is effectively broken as
[it doesn’t support nesting](https://github.com/nvim-lua/plenary.nvim/issues/395).

## 🙏 Acknowledgments

The SVG from the logo comes from
[Uxwing](https://uxwing.com/handshake-color-icon/).

## 🔗 See also

- [Coerce](https://github.com/gregorias/coerce.nvim) — My Neovim plugin for case conversion.
- [Toggle](https://github.com/gregorias/toggle.nvim) — My Neovim plugin for toggling options.
- [Coop’s design was presented as an approach structured concurrency in Neovim.](https://github.com/neovim/neovim/issues/19624#issuecomment-2466700118)
- [Reddit thread](https://www.reddit.com/r/neovim/comments/1gnz7tl/beta_coopnvim_a_structured_concurrency_plugin_for/)

[Lazy]: https://github.com/folke/lazy.nvim
[Nio]: https://github.com/nvim-neotest/nvim-nio
