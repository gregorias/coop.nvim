# How Coop works

This document is a guide explaining the design and implementation of Coop’s
internals.

## Using callbacks to build coroutines

The first feature Coop provides are non-blocking operations with
[a convenient coroutine syntax](https://gregorias.github.io/posts/using-coroutines-in-neovim-lua/).
Coop does that by reusing callback-based, non-blocking operations from Neovim’s
standard library.
To understand Coop’s mechanism, let’s first draw how a callback-based function
provides concurrency:

![A sequence diagram of non-blocking I/O with callbacks](/assets/Nonblocking%20IO%20with%20callbacks.png)

Conceptually, there’s some I/O thread (e.g., a Libuv event loop) that works
parallel to the main thread.
When we start a non-blocking operation, we only schedule that operation on the
I/O thread (the `fs_read_cb` call).
The I/O thread eventually yields to the main thread (`yield`).
Once the scheduled operation is ready, the I/O thread calls the callback that
was provided in `fs_read_cb` (`cb()`).

We can turn any non-blocking function into a coroutine like so:

![A sequence diagram of non-blocking I/O with a coroutine](/assets/Nonblocking%20IO%20with%20coroutines.png)

What happens here is:

1. The coroutine wraps the `fs_read_cb` call and yields as soon as the
   `fs_read_cb` yields.
2. The coroutine uses a callback that makes the I/O thread resume the
   coroutine. The actual result processing happens within the body of the
   coroutine.

This neat callback-to-coroutine wrapping keeps the non-blocking property, while
coroutine syntax makes it all look sequential syntactically.

Luckily for us, conversion from callbacks to coroutines can be written
as a generic function. I’ve provided a recipe for it in [my blog post](https://gregorias.github.io/posts/using-coroutines-in-neovim-lua/),
and it also exists in Coop as
[`coroutine-utils.cb_to_co`](https://github.com/gregorias/coop.nvim/blob/e7a0793163141e95a7034381cf392df988fc779f/lua/coop/coroutine-utils.lua#L20).

## Task abstraction

Lua coroutines are already convenient and powerful, but Coop wanted to provide
additional functionalities expected from a concurrency framework:

- Cancellation — The programmer should be able to do things like timing out
  long-running operations.
- Awaiting — The programmer should be able to implement non-trivial await
  strategies, e.g., wait for the first operation of many to complete.
- Error-handling — The programmer should be able to throw and catch errors in
  coroutines.

Coop’s tasks are the abstraction that extends `coroutines` with aforementioned
features.

A Coop task is an extension of a Lua thread (coroutine) with a `Future` that
enables holding and waiting for results. It comes with familiar functions that
work just like for native coroutines except that they operate on tasks and task
functions:

- `task.create`
- `task.running`
- `task.resume`
- `task.yield`
- `task.status`

### Awaiting

To implement result holding and awaiting, Lua tasks hold
a [`Future`](https://github.com/gregorias/coop.nvim/blob/main/lua/coop/future.lua).

Whenever a new task is created through `task.create`, the task function’s
result is wired to complete the bundled future:

```lua
task.create = function(tf)
  local new_task
  -- …
  new_task.thread = coroutine.create(function(...)
    new_task.future:complete(tf(...))
  end)
  -- …
end
```

The future itself is a queue of callbacks to be called whenever its completed.

In Coop, a task that ends resumes waiting tasks:

```lua
Future.complete = function(self, ...)
  -- …
  self.results = pack(...)
  -- …
  for _, cb in ipairs(self.queue) do
    cb(unpack(self.results, 1, self.results.n))
  end
end
```

Awaiting is essentially implemented as adding a callback to a future’s queue.
The callback resumes the awaiting tasks.

### Cancellation

Tasks come with a cancel method, `task.cancel`, that cancels a running task.
`task.cancel` resumes the task and causes `error("cancelled")` to be thrown
inside the task’s body.
This is achieved by having a `cancelled` flag inside the task table and
checking for the flag inside `task.yield`:

```lua
task.yield = function(...)
  coroutine.yield()
  -- After resume.
  this = task.running()
  if this.cancelled then
    -- Clear the cancelled flag, so that the user can implement ignoring.
    task.cancelled = false
    error("cancelled")
  end
  -- …
end
```

This will cause the task to effectively stop and become dead, and everyone that
awaits the task will also get the error.

#### Cancellation cleanup

The cancellation feature complicates cleanup.
In [Using callbacks to build coroutines](#using-callbacks-to-build-coroutines),
I explained how the I/O thread resumes a suspended coroutines,
but now `task.cancel` becomes an alternative way to resume the task.
If that happens, we need to stop any started background threads or clean up
after them if they finish.

Coop provides an upgraded
[`task-utils.cb_to_tf`](https://github.com/gregorias/coop.nvim/blob/ed8ceabc0b97ff77495112a2dc4f89cf7b0aa97e/lua/coop/task-utils.lua#L34)
that accepts callbacks for cleanup.
These callbacks are used in Libuv wrappers to, for example, deallocate file
descriptors upon cancellation:

```lua
M.fs_open = cb_to_tf(vim.uv.fs_open, {
  cleanup = function(err, fd)
    if not err then
      vim.uv.fs_close(fd)
    end
  end,
})
```

### Error-handling

The last task feature is the ability to catch errors.
`task.create` doesn’t have any facilities for that as it only captures the
return value of the task function:

```lua
task.create = function(tf)
  -- …
  new_task.thread = coroutine.create(function(...)
    new_task.future:complete(tf(...))
  end)
  -- …
end
```

Coop captures error by extending `coroutine.resume` in `task.resume`.
`coroutine.resume` behaves like `pcall` in that it turns thrown errors into
return values, so `task.resume` just watches for that:

```lua
task.resume = function(t, ...)
  -- …
  local results = pack(coroutine.resume(t.thread, ...))
  -- …
  if not results[1] then
    t.future:error(results[2])
  end
  -- …
end
```

`Future.error` is a counterpart to `Future.complete` for saving errors.

## copcall

In Lua 5.1, `pcall` and coroutine functions do not mix.
You can’t yield across `pcall` calls.
This severely limits how coroutine functions can be used as we can’t catch
errors (and therefore shouldn’t throw them at all).

A Coop’s design goal was to make task functions feel like synchronous
functions, so I added `copcall`.
`copcall` is a coroutine function that has an interface similar to `pcall`
except it expects coroutine functions.
`copcall` works by launching a new coroutine and resuming over it until it is dead.
It works, because `coroutine.resume` works like `pcall`.

```lua
-- pseudocode
M.copcall = function(f_co, ...)
  local thread = coroutine.create(f_co)
  local results = coroutine.resume(thread)
  while thread_not_dead(results) do
    results = coroutine.resume(thread, coroutine.yield())
  end
  return results
end
```
