# How Coop works

This document is a guide explaining the design and implementation of Coop’s
internals.

## Using callbacks to build coroutines

Neovim already provides non-blocking operations through the use of callbacks.

![A sequence diagram of nonblocking I/O with callbacks](/assets/Nonblocking%20IO%20with%20callbacks.png)

Conceptually, there’s some I/O thread (e.g., a Libuv event loop) that works
parallel to the main thread.
When we start a non-blocking operation, we only schedule that operation on the
I/O thread.
The I/O thread yields to the main thread and once the scheduled operation is
ready, calls the callback.
It works, but results in hard to manage code.

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
