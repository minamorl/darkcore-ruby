# The Monad Zoo

darkcore ships a small zoo of monads: `Maybe` (`Just` / `Nothing`), `Result` (`Darkcore::Ok` /
`Darkcore::Err`), `Validation` (`Success` / `Failure`), `Either` (`Left` / `Right`), and `State`.

Each monad writes **only `pure` and `bind`**. `fmap` / `ap` are derived automatically by the shared
`Monad` mixin, so there is no per-type boilerplate.

```ruby
include Darkcore

# Result: short-circuits while carrying a failure reason
Result.try { Integer("21") }.bind { |n| Result.ok(n + 1) }  # => Ok(22)

# Validation: does not short-circuit — collects every error (ap accumulates)
V = Darkcore::Validation
V.success(->(a) { ->(b) { [a, b] } })
 .ap(V.failure("e1"))
 .ap(V.failure("e2"))  # => Failure(["e1", "e2"])
```

## The one deliberate exception: `Validation#ap`

`Validation#ap` intentionally overrides the `Monad`-derived version. An error-accumulating
applicative **cannot** be derived from a monad's `bind`, because `bind` must always short-circuit.
That impossibility is precisely the reason `Validation` exists: it is the applicative that keeps
going and gathers all failures, which `bind` can never do.

## Namespace separation

`Darkcore::Ok` / `Darkcore::Err` are kept in a separate namespace from `Beryl::Ok` / `Beryl::Err`,
so the two result envelopes never collide when both libraries are loaded.
