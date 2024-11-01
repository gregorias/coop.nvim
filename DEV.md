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

## Glossary

A **coroutine function** is a Lua function, which may call `coroutine.yield`.
A coroutine function must always be executed within a **coroutine**.

A **plain coroutine function** is a coroutine function that doesn’t implement
any protocol for its yields.
A plain coroutine function doesn’t return any values in yields nor expect any
values from them.

## ADRs

### On using tasks (coroutine + future)

This record is about the decision to implement the `task` interface that
replaces `coroutine`.

I want the framework to treat coroutine functions almost like regular functions
and have the capability to wait for results of a parallelized operation with futures.
A (coroutine) function can return in two ways: return values or throw
an error.
The error is only caught by whoever calls `coroutine.resume`, because we can’t
use `pcall` with coroutine functions.
That would mean that sometimes the error would get caught by the UV thread and
get lost as I can’t change how the UV thread works.
A lost error means that we would end up with a dangling future.
I decided that the future interface would be better if it was total, i.e.,
future always finishes when its coroutine is dead.
To achieve that I concluded that a small error-catching wrapper on top of
`coroutine.resume` (called “task”) would do the trick and the cost of this is
worth it: the implementation is dead simple in the end.

In summary, pure coroutines lack the ability to store their results.
Tasks add that useful capability at a low cost.

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
