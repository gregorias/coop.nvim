# 🛠️ Developer documentation

This is a documentation file for developers.

## Dev environment setup

This project requires the following tools:

- [Commitlint]
- [Just]
- [Lefthook]
- [Stylua]

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

The project overall had the following design guidelines:

- Extend coroutines without replacing them. Keep things simple by extending how
  coroutines work and keeping as much of their behaviour as reasonable.
- Make asynchronous code behave similarly to synchronous code.

### On using tasks (coroutine + future)

This record is about the decision to implement the `task` interface that
replaces `coroutine` instead of using pure coroutines.

### The need to wait

You can’t build awaiting primitives with pure coroutines.
The proof would look something like this: Lua is single-threaded, so something
needs to wake and run waiting threads. That means that someone needs keep a list
of waiters. You can’t store such data in pure coroutines.

The awaiting feature requires bundling in a waiting queue (a future) together
with a thread.

### The need to capture errors

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

### On a single await function

I decided that a future should expose a single await function that can work in
three modes:

- an asynchronous task function
- a callback-based function
- busy waiting

All three cases are useful in practice and a single function makes the
interface more fluent and more elegant.
I just found that having three different names was clumsy.

### On `Future._call`

I made `await` available under a function call, so that people can use
awaitables as if they were task functions.
This is inline with the design goal to avoid asynchronous boilerplate.

### On rethrowing errors in `await`

`await` rethrows errors. This makes `await` behave like a regular function would.

[Commitlint]: https://github.com/conventional-changelog/commitlint
[Lefthook]: https://github.com/evilmartians/lefthook
[Just]: https://just.systems/
[Stylua]: https://github.com/JohnnyMorganz/StyLua
