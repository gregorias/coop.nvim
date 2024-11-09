# How Coop works

This document is a guide explaining the design and implementation of Coop’s
internals.

## Using callbacks to build coroutines

The first feature Coop provides are non-blocking operations with
[a convenient coroutine syntax](https://gregorias.github.io/posts/using-coroutines-in-neovim-lua/).
Coop does that by reusing callback-based, non-blocking operations that Neovim
already provides.
To understand Coop’s mechanism, let’s first draw how a callback-based function
provides concurrency:

![A sequence diagram of non-blocking I/O with callbacks](/assets/Nonblocking%20IO%20with%20callbacks.png)

Conceptually, there’s some I/O thread (e.g., a Libuv event loop) that works
parallel to the main thread.
When we start a non-blocking operation, we only schedule that operation on the
I/O thread (the `fs_read_cb` call).
The I/O thread yields to the main thread (`yield`). Once the scheduled
operation is ready, the I/O thread calls the callback that was provided in
`fs_read_cb` (`cb()`).

We can turn any non-blocking function into a coroutine like so:

![A sequence diagram of non-blocking I/O with a coroutine](/assets/Nonblocking%20IO%20with%20coroutines.png)

What happens here is:

1. The coroutine wraps the `fs_read_cb` call and yields as soon as the
   `fs_read_cb` yields.
2. The coroutine uses a callback that makes the I/O thread resume the
   coroutine. The actual result processing happens within the body of the
   coroutine.

This neat callback-to-coroutine wrapping keeps the non-blocking property, while
coroutine syntax makes it all seem sequential.

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
work just like for native coroutines except they operate on tasks and task functions:

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
  -- …
  thread = coroutine.create(function(...)
    future:complete(tf(...))
  end)
  -- …
end
```

The future itself is a queue a callbacks to be called whenever its completed.
In Coop, a thread that ends resumes threads that wait on it.

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
The callback resumes the awaiting thread.

### Cancellation

TODO: Explain cancellation.

### Error-handling

TODO: Explain the extension to `task.resume`.

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
