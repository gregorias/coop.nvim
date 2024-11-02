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
looks synchronous like async/await in other languages.

Coop was designed to

- Be simple. [It should be easy to explain.](./How it works.md)
- Stay close to native Lua coroutines and Lua’s idioms. Coop interface feels
  like a synchronous interface would and minimizes surprizes.
- Come with batteries included for Neovim.

Here’s what else you can expect from Coop:

- True parallelism with a rich set of control operators.
- A flexible cancellation mechanism.
- Extensibility — Turn any callback-based function into a task function.

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

A good introduction to Coop or any framework is to look at code examples.
Check out [`lua/coop/examples.lua`](/lua/coop/examples.lua):

[`search_for_readme`](https://github.com/gregorias/coop.nvim/blob/0e2082500707f2a143ff924ad36577c348148517/lua/coop/examples.lua#L40)
shows a hello world of asynchronicity: filesystem operations.
Notice that, although `search_for_readme` is non-blocking, it looks _exactly_
like its synchronous counterpart would look like.
One tiny caveat is that you need to spawn it in your main, synchronous thread:
`coop.spawn(search_for_readme)`.

[`sort_with_time`](https://github.com/gregorias/coop.nvim/blob/0e2082500707f2a143ff924ad36577c348148517/lua/coop/examples.lua#L72)
shows that Coop achieves true parallelism.
It launches parallel timers with `coop.spawn` and uses a
`coop.control.as_completed` to conveniently capture results as each timer
completes.

[`run_parallel_search`](https://github.com/gregorias/coop.nvim/blob/0e2082500707f2a143ff924ad36577c348148517/lua/coop/examples.lua#L98)
is the final example and it shows the flexible cancellation mechanism together
with error handling.

### Interface guide

#### Task

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
The litmus test for me was whether I would be able to write a guide into the
internals that is easy to follow for someone that knows coroutines (this is TBD).

In terms of features, Coop has a more powerful cancellation mechanism.
In Coop, task cancellation causes an error to be thrown in the affected task.
This allows the programmer to implement any custom cancellation logic, e.g., cancelling child tasks or unloading resources.
As far as I can tell, **Nio doesn’t let you safely unload resources upon cancellation** as
[it just makes the task dead](https://github.com/nvim-neotest/nvim-nio/blob/a428f309119086dc78dd4b19306d2d67be884eee/lua/nio/tasks.lua#L113-L116).

### Plenary Async

## 🙏 Acknowledgments

The SVG from the logo comes from
[Uxwing](https://uxwing.com/handshake-color-icon/).

## 🔗 See also

- [Coerce](https://github.com/gregorias/coerce.nvim) — My Neovim plugin for case conversion.
- [Toggle](https://github.com/gregorias/toggle.nvim) — My Neovim plugin for toggling options.

[Lazy]: https://github.com/folke/lazy.nvim
[Nio]: https://github.com/nvim-neotest/nvim-nio
