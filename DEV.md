# 🛠️ Developer documentation

This is a documentation file for developers.

## Dev environment setup

This project requires the following tools:

- [Commitlint]
- [Just]
- [Lefthook]

Install lefthook:

```shell
lefthook install
```

## ARDs

### Using `coroutine.resume` return format in coroutine functions

Coroutine functions such as `Future.await` first return a success boolean and
then either an error or return values.

An alternative would have been to rethrow errors, but this is not workable,
because `Future.await` is a coroutine function.
Since yields can’t cross pcalls, clients wouldn’t be able to use pcalls and
therefore catch those errors.

[Commitlint]: https://github.com/conventional-changelog/commitlint
[Lefthook]: https://github.com/evilmartians/lefthook
[Just]: https://just.systems/
