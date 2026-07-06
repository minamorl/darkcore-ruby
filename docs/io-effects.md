# IO as tagged effects (Category R / Category V)

IO is not pushed out into an opaque thunk. Every IO action is a **tagged effect — plain,
inspectable, swappable data**. `say`, `ask`, `read`, `write` are peers of any other tag, so they
line up horizontally instead of hiding behind a special "outer layer".

```ruby
include Darkcore::IOEffects
# say / ask / read / write / append / delete / exists / list_dir
# getenv / now / rand / shell

program =
  read("/tmp/x").bind { |body| say(body.upcase) }
```

## Category R — the real OS

```ruby
Darkcore.run(program, Darkcore::IOEffects.real_handlers)
```

Runs against the actual filesystem, stdin, clock and shell. Side effects happen in order because
`bind` splices continuations, so `read → say` is fixed as structure.

## Category V — a fully in-memory virtual world

```ruby
world = Darkcore::VirtualWorld.new(files: { "/tmp/x" => "hi\n" })
Darkcore.run(program, world.handlers)
world.outputs # => ["HI\n"]
```

No OS contact at all: files are a Hash, stdin is an array, the clock is fixed, `rand` is
deterministic. The same IO logic runs identically on a real disk and on a Hash, which means **IO
programs are testable with no mocking library, no OS contact, and full determinism** — something the
thunk-based style cannot do.

## Why "ordinary IO" comes out cleanly here

Three things do the work:

1. **Sequential order is guaranteed.** `bind` / `then_` splice the continuation `k`, so the effect
   order is fixed as structure. The property IO cares about most — "things happen in order" — is
   free.
2. **A result feeds the next effect.** `ask(:name).bind { |name| ... }` lets an input value flow
   into what follows. IO return values form ordinary data dependencies.
3. **`run` is a trampoline.** An iterative interpreter (not recursion) avoids the deep-tree stack
   problem of naive Free monads. Roll a die 100k times and the stack still holds.

## Coverage and honest gaps

The current tags cover stdout/stderr/stdin, file read/write/append/delete/exists/ list_dir, and
getenv/now/rand/shell. Not yet covered: streaming reads (do not `File.read` a GB file at once),
binary/encoding concerns, exceptions, sockets/ HTTP, and concurrent IO. Exception handling in
particular is a design decision — whether a failed `read` ends at `:pure` or falls into an error tag
received by a Result-shaped category.
