# darkcore

[![ci](https://github.com/minamorl/darkcore-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/minamorl/darkcore-ruby/actions/workflows/ci.yml)
![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.2-CC342D?logo=ruby&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue)

A monad zoo plus a **single Effect type (Freer monad)** for Ruby. A port of the Python
[minamorl/darkcore](https://github.com/minamorl/darkcore).

Every node is represented by one kind of tagged effect. IO is not an opaque thunk but an
**inspectable, swappable tagged effect (plain data)**. The same program is never rewritten — you
**swap only the handler map** to choose a "category" such as real IO, pure record, or dry-run. The
interpreter runs on a **trampoline (iteration)**, so even deep effect trees never blow the stack. No
operator overloading is used anywhere; composition is done entirely through method names (`bind` /
`fmap` / `ap`).

## Requirements

Ruby >= 3.2

## Installation

```ruby
# Gemfile
gem "darkcore"
```

## Quick start

```ruby
require "darkcore"

def say(m) = Darkcore.op(:say, m)
def ask(q) = Darkcore.op(:ask, q)

program =
  say("What is your name?").seq(
    ask(:name).bind { |name| Darkcore.pure("hello #{name}") }
  )

record = { say: ->(_m) { nil }, ask: ->(_) { "TEST" } }
Darkcore.run(program, record) # => "hello TEST"  (no OS contact, deterministic)
```

## Documentation

- [The Single Effect Type (Freer monad)](docs/effect-system.md) — how `pure`, `bind`, `fold`, `step`
  and category selection work.
- [IO as tagged effects](docs/io-effects.md) — Category R (real OS) vs Category V (in-memory virtual
  world), and why ordinary IO comes out cleanly.
- [The Monad Zoo](docs/monad-zoo.md) — Maybe / Result / Validation / Either / State, and why
  `Validation#ap` is the one deliberate exception.
- [Examples and Tests](docs/examples.md) — runnable examples and the test suite.
- [Spec Compliance](docs/spec-compliance.md) — the behavioral pins this gem locks against.

## License

MIT
