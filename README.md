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

Coop was designed to be simple by being as close to native Lua coroutines as
possible while enabling features expected from a structured concurrency
framework:

- Ability to cancel in-flight tasks or task groups.
- Ability to wait for tasks to finish and inspect results or errors.
- Ability to work with any asynchronous function whether it uses callbacks or
  `coroutine.yield`.
- Ability to launch and wait for parallelized operations, e.g., launching
  multiple asynchronous filesystem crawlers.

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

`search_for_readme` shows a hello world of asynchronicity: filesystem operations.
Notice that, although `search_for_readme` is non-blocking, it looks _exactly_
like its synchronous counterpart would look like.
One tiny caveat is that you need to spawn it in your main, synchronous thread:
`coop.spawn(search_for_readme)`.

`sort_with_time` shows that Coop achieves true parallelism.
It launches parallel timers with `coop.spawn` and uses a
`coop.control.as_completed` to conveniently capture results as each timer
completes.

### Interface guide

#### Task

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
