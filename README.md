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

## ✅ Comparison to similar tools

### `nvim-nio`

- TODO: Simpler in principle.
- TODO: Ability to define cancel hooks.

## 🙏 Acknowledgments

The SVG from the logo comes from
[Uxwing](https://uxwing.com/handshake-color-icon/).

## 🔗 See also

- [Coerce](https://github.com/gregorias/coerce.nvim) — My Neovim plugin for case conversion.
- [Toggle](https://github.com/gregorias/toggle.nvim) — My Neovim plugin for toggling options.

[Lazy]: https://github.com/folke/lazy.nvim
