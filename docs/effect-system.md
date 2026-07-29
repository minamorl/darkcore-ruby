# The Single Effect Type (Freer monad)

darkcore represents **every node with one kind of tagged effect**. There is no `Pure` vs `Impure`
split: `pure` is just an effect that carries no continuation (a _closed_ effect, `k = nil`). What
used to be called "purity" is demoted to a single closed operation, `:pure`.

```ruby
require "darkcore"

# The effect vocabulary — this only builds tags. No IO happens here.
def say(m) = Darkcore.op(:say, m)
def ask(q) = Darkcore.op(:ask, q)

# program = a tree of effects (plain data, nothing has run yet)
program =
  say("What is your name?").seq(
    ask(:name).bind { |name| Darkcore.pure("hello #{name}") }
  )
```

## Choosing a category with a handler map

The same `program` (a single value, never rewritten) flows into different **categories** by swapping
only the handler map you pass to `run`. `program` itself is immutable.

```ruby
# real IO vs a deterministic record — the program does not change
real   = { say: ->(m) { puts m; nil }, ask: ->(_) { $stdin.gets.chomp } }
record = { say: ->(m) { nil },         ask: ->(_) { "TEST" } }

Darkcore.run(program, real)   # touches the real terminal
Darkcore.run(program, record) # => "hello TEST"  (no OS contact, deterministic)
```

## Why `bind` is free

`bind` embeds **no category-specific operation**. It only grafts continuations onto the tree — it is
_free_ (meaning-less) on purpose.

```ruby
def bind(&f)
  if pure?              # closed node
    f.call(payload)     # just splice the continuation (structural, zero algebra)
  else
    Effect.new(tag, payload, ->(x) { k.call(x).bind(&f) })  # grow the tree
  end
end
```

Algebra (the interpretation of each category) is allowed to appear in exactly **two** places: the
`on_return` of `fold` (how a closed point is read) and the `handler` for each effect tag.

```ruby
Darkcore.fold(program, on_return: ->(x) { x.upcase }, handlers: record)
# => "HELLO TEST"
```

## Trampolined interpreter

`fold` / `run` are iterative (a `loop`), not recursive. A deep effect tree — even 100k nodes — never
raises `SystemStackError`.

## Stepping instead of running: `Darkcore.step`

`fold` runs to completion, so a program cannot be paused part-way and picked up later. `step`
advances the tree by exactly one node and interprets nothing, returning what the program is waiting
on as data:

| Result                          | Meaning                                                                           |
| ------------------------------- | --------------------------------------------------------------------------------- |
| `Done(value)`                   | The closed `:pure` effect was reached — this is the final value.                  |
| `Pending(tag, payload, resume)` | The next effect to interpret. `resume.call(result)` returns the rest of the tree. |

```ruby
program = Darkcore.op(:ask, "name").bind { |name| Darkcore.op(:say, "hello #{name}") }

state = Darkcore.step(program)
state.tag                    # => :ask
state.payload                # => "name"    (nothing has run)
Darkcore.step(state.resume.call("mina")).payload # => "hello mina"
```

Because `Pending` is plain data, the caller becomes the scheduler: park a program on IO and yield to
another fiber, inspect which effect an in-flight program is blocked on, or resume the same `Pending`
more than once. `fold` is written as a loop over `step`, so the two can never drift apart.

## Design lineage

This is exactly the shape of algebraic effects: `return` (purity) is folded into the effect
signature as one operation, the same choice Koka, Eff and freer-simple make. Because purity is not a
special base but a closed operation, the Pure/Impure dichotomy disappears and everything composes as
one type.

The honest caveat: purity does not vanish. It is _relabeled_ as the closed `:pure` effect and folded
into the single type. A terminator is always required, so the closed point is the one place that
stays "closed". The upshot is that you only need to supply algebra at that closed point and at each
effect tag — and each tag can be assigned a different category.
