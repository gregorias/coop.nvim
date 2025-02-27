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

Coop was designed with the following principles:

- Be simple. [Coop should be easy to explain.](How%20it%20works.md)
- Stay close to native Lua coroutines and Lua’s idioms.
- Come with batteries included for Neovim.

Here’s what else you can expect from Coop:

- True parallelism with a rich set of control operators.
- A flexible cancellation mechanism.
- Extensibility — You can turn any callback-based function into a task
  function. If the callback-based function is non-blocking, so will the task
  function be.

## ⚡️ Requirements

- Neovim 0.10+

## 📦 Installation

Install the plugin with your preferred package manager, such as [Lazy]:

```lua
{
  "gregorias/coop.nvim",
}
```

or [Rocks]:

```plaintext
:Rocks install coop.nvim
```

## 🚀 Usage tutorial

This section is a Coop tutorial by example.

### Hello, world

Let’s start with the hello world of asynchronicity: reading a file.
Below is an end-to-end code that shows how to concurrently read two files with
Coop:

```lua
local coop = require("coop")
local uv = require("coop.uv")

--- Reads a file.
---
---@async
---@param path string
---@return string
function readFileAsync(path)
  local err_open, fd = uv.fs_open(path, "r", 438)
  assert(err_open == nil)
  local err_fstat, stat = uv.fs_fstat(fd)
  assert(err_fstat == nil)
  local err_read, data = uv.fs_read(fd, stat.size, 0)
  assert(err_read == nil)
  local err_close = uv.fs_close(fd)
  assert(err_close == nil)
  return data
end

--- Read `foo.txt` and `bar.txt` concurrently.
local foo_task = coop.spawn(readFileAsync, "foo.txt")
local bar_task = coop.spawn(readFileAsync, "bar.txt")

--- Wait 1s for both tasks to finish and print their results.
print(foo_task:await(1000), bar_task:await(1000))
```

### Advanced examples

For more advanced examples, check out [`lua/coop/examples.lua`](/lua/coop/examples.lua):

[`search_for_readme`](https://github.com/gregorias/coop.nvim/blob/0e2082500707f2a143ff924ad36577c348148517/lua/coop/examples.lua#L40)
shows filesystem operations.
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

## 🦮 Interface guide

This section introduces the essential interfaces.

In Coop, the two main abstractions are **task functions** and **tasks**.
**Task functions** are regular Lua functions that may call `task.yield`.
Task functions are effectively asynchronous functions.
Whenever you see a function in Coop that’s annotated with `@async`, it is a
task function.
You may nest task functions freely like you would nest regular functions.

The main caveat for **task functions** is that to run them in your top-level
synchronous code, you need to wrap them in a **task**, which represents a
thread.
You usually do the wrapping with `coop.spawn` (see aforementioned examples).

### Task

A **task** is an extension of a Lua coroutine with three capabilities:

- Holding results (including errors)
- Awaiting
- Cancellation

A task behaves like a coroutine and comes with its own equivalent functions:

```lua
--- Creates a task from a task function.
---
---@param task_function @async fun
---@return Coop.Task task
task.create

--- Resumes a task.
---
---@param task Coop.Task
---@param ...
---@return boolean success
---@return any ... results
task.resume

--- Yields from a task functions it’s in.
---
--- Yield throws `error("cancelled")` if in a cancelled task.
---
---@async
---@param ...
---@return ...
task.yield

--- Returns the task’s status.
---
---@param task Coop.Task
---@return string "running" | "suspended" | "normal" | "dead"
task.status

--- Returns the running task.
---
---@return Coop.Task?
task.running
```

There’s also `pyield` variant of `yield` that returns `success, results`
instead of throwing an error.

Instead of `task.create`, you should usually use `coop.spawn`, which creates a
new task and resumes it.

Tasks come with two additional functions.
A cancel function (which is also a method):

```lua
--- Cancels the task.
---
--- The cancelled task will throw `error("cancelled")` in its yield.
--- If you intercept cancellation, you need to unset the `cancelled` flag with
--- with Task:unset_cancelled.
---
--- `cancel` resumes the task. It’s like sending a cancellation signal that the task needs to
--- handle.
---
---@param task Coop.Task the task to cancel
---@return boolean success
---@return any ... results
function task.cancel(task)
  -- …
end

--- Unsets the cancellation flag.
---
---@param task Coop.Task
function task.unset_cancelled(task)
  -- …
end

--- Returns whether the task is cancelled.
---
---@param task Coop.Task
---@return boolean is_cancelled
function task.is_cancelled(task)
  -- …
end
```

And an await method that has three overload and a protected variant.

```lua
-- Awaits task completion.
function task.await(self, cb_or_timeout, interval)
end

-- task.await() is a task function that waits for the task finish and return a
-- result
result = task:await()

-- task.await(cb) is a callback-based function that calls the callback once the
-- task is finished.
-- It doesn’t wait for the task.
task:await(function(success, result) end)

-- task.await(timeout, interval) is a blocking function that uses vim.wait to
-- implement a busy-waiting loop.
task:await(1000, 100) -- Wait for 1s for the task to finish. Check every 100ms

--- Awaits task completion in a protected mode.
---
--- This variant of await doesn’t rethrow errors.
--- Instead it returns false, err_msg.
---
---@async
---@param self Coop.Task
---@return boolean success
---@return any ... results
function task.pawait(self)
  -- …
end
```

Tasks implement a call operator that calls `await`. This allows for a fluent
interface where tasks appear as if they were regular task functions:

```lua
local get_result_1 = coop.spawn(compute, 100)
local get_result_2 = coop.spawn(compute, 200)
local result = get_result_1()
```

The essential task-related functions live in `coop.task` and `coop.task-utils` modules.

## 📙 Library reference

### `coop.control`

[The `coop.control` module](https://github.com/gregorias/coop.nvim/blob/main/lua/coop/control.lua)
provides utilities for combining task functions and awaitables.

<details>

<summary>Functions</summary>

```lua
--- Runs tasks in the sequence concurrently.
---
--- If all tasks are completed successfully, the result is an aggregate list of returned
--- values. The order of result values corresponds to the order of tasks.
---
--- The first raised exception is immediately propagated to the task that awaits on gather().
--- Active tasks in the sequence won’t be cancelled and will continue to run.
---
--- Cancelling the gather will cancel all tasks in the sequence.
---
---@async
---@param tasks Coop.Task[] the list of tasks.
---@return any ... results
M.gather = function(tasks) end

--- Protects a task function from being cancelled.
---
--- The task function is executed in a new task.
---
--- If no cancellation is taking place, `shield(tf, ...)` is equivalent to `tf(...)`.
---
--- If the task wrapping `shield` is cancelled, the task function is allowed to complete.
--- Afterwards `shield` throws the cancellation error.
---
--- If it is desired to completely ignore cancellation, `shield` should be combined with `copcall`.
---
---@async
---@param tf async function The task function to protect.
---@param ... ... The arguments to pass to the task function.
---@return any ... The results of the task function.
M.shield = function(tf, ...) end

--- Creates a task function that times out after the given duration.
---
--- If no timeout is taking place, `timeout(duration, tf, ...)` is equivalent to `tf(...)`.
---
--- If a timeout happens, `timeout` throws `error("timeout")`.
---
--- If the returned task function is cancelled, so is the wrapped task function.
---
---@async
---@param duration integer The duration in milliseconds.
---@param tf async function The task function to run.
---@param ... ... The arguments to pass to the task function.
---@return ... ... The results of the task function.
M.timeout = function(duration, tf, ...) end

--- Waits for any of the given tasks to complete.
---
---@async
---@param tasks Coop.Task[]
---@return Coop.Task done The first task that completed.
---@return Coop.Task[] done The remaining tasks.
M.await_any = function(tasks) end

--- Awaits all tasks in the list.
---
---@async
---@param tasks Coop.Task[]
---@return table results The results of the tasks.
M.await_all = function(tasks) end

--- Asynchronously iterates over the given awaitables and waits for each to complete.
---
---@async
---@param tasks Coop.Task[]
M.as_completed = function(tasks) end
```

</details>

### `coop.lsp.client`

[The `coop.lsp.client` module](https://github.com/gregorias/coop.nvim/blob/main/lua/coop/lsp/client.lua)
provides a task function implementation for
[`Client:request`](https://neovim.io/doc/user/lsp.html#Client%3Arequest()).

### `coop.mpsc-queue`

[The `mpsc-queue` module](https://github.com/gregorias/coop.nvim/blob/main/lua/coop/mpsc-queue.lua)
provides a multiple-producer single-consumer concurrent
queue with an asynchronous `pop` method.

<details>

<summary>Code example</summary>

```lua
local MpscQueue = require('coop.mpsc-queue').MpscQueue
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

### `coop.subprocess`

[The `subprocess` module](https://github.com/gregorias/coop.nvim/blob/main/lua/coop/subprocess.lua)
provides a way to launch subprocesses and control their I/O with task functions.

<details>

<summary>Code example</summary>

```lua
local coop = require("coop")
local subprocess = require("coop.subprocess")

---@async
function pass_printf_to_cat()
  local printf = subprocess.spawn("printf", {
    args = { "Hello, world!" },
    stdio = { nil, subprocess.PIPE },
  })
  local cat = subprocess.spawn("cat", {
    stdio = { printf.stdout, subprocess.STREAM },
  })
  vim.print(cat.stdout:read_until_eof())
  printf:await()
  cat:await()
end

coop.spawn(pass_printf_to_cat)
```

</details>

### `coop.ui`

[The `ui` module](https://github.com/gregorias/coop.nvim/blob/main/lua/coop/ui.lua)
provides task function versions of functions in
[`vim.ui`][Neovim UI] (`input` and `select`).

### `coop.uv`

[The `uv` module](https://github.com/gregorias/coop.nvim/blob/main/lua/coop/uv.lua)
provides task function versions of asynchronous functions in
[`vim.uv`][Neovim UV].

### `coop.uv-utils`

[The `uv-utils` module](https://github.com/gregorias/coop.nvim/blob/main/lua/coop/uv-utils.lua)
provides the following:

- `sleep`, a function that puts the running thread to sleep for a number of
  milliseconds.
- `StreamReader` and `StreamWriter`, two wrappers that turn callback-based
  Libuv streams (`uv_stream_t`) into objects with asynchronous task functions.

### `coop.vim`

[The `vim` module](https://github.com/gregorias/coop.nvim/blob/main/lua/coop/vim.lua)
provide the task function version `vim.system`.

<details>

<summary>Stream example</summary>

```lua
local coop = require("coop")
local StreamReader = require('coop.uv-utils').StreamReader
local StreamWriter = require('coop.uv-utils').StreamWriter

local fds = vim.uv.pipe({ nonblock = true }, { nonblock = true })
local sr = StreamReader.from_fd(fds.read)
local sw = StreamWriter.from_fd(fds.write)

local result = coop.spawn(function()
  sw:write("Hello, world!")
  sw:close()
  local data = sr:read_until_eof()
  sr:close()
  return data
end).await(5000, 1)

assert(result == "Hello, world!")
```

</details>

## FAQ

### How do I block until an asynchronous function is done in synchronous code?

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

### Can I mix coroutine functions and task functions?

No.

You can not use coroutine functions in task functions, because the coroutine
yield doesn’t handle cancellation.

You can not use task functions in coroutines, because `task.yield` requires
running in a task.

You may however convert coroutine functions to task functions with
`coop.task-utils.co_to_tf`.

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
[Neovim UI]: https://neovim.io/doc/user/lua.html#vim.ui
[Neovim UV]: https://neovim.io/doc/user/luvref.html
[Rocks]: https://github.com/nvim-neorocks/rocks.nvim
