# Spec Compliance

This gem conforms to the behavioral lock in
`spec-system/pins/domains/darkcore.spec`. Each pin below is a hard constraint the
implementation must satisfy.

| pin | implementation |
| --- | --- |
| `core.effect.node = single_tagged` | every node is one kind of `Effect(tag, payload, k)` (`lib/darkcore/effect.rb`) |
| `core.pure.encoding = closed_effect` | `pure` = the `:pure` tag with `k = nil`, a closed effect |
| `core.bind.free` | `bind` only splices continuations; it holds no category-specific algebra |
| `core.algebra.site in [handler, on_return]` | algebra appears only in `fold`'s `on_return` and per-tag `handler` |
| `api.no_operator_overload` | no operators defined; composition is `bind` / `fmap` / `ap` |
| `api.bind_name = method_bind` | bind is the `bind` method |
| `api.derive.from in [pure, bind]` | `Monad` derives `fmap` / `ap` from `pure` + `bind` |
| `run.strategy = trampoline` / `no_naive_recursion` | `fold` / `run` execute via a `loop` (iteration) |
| `category.selection = handler_map` | swapping `handlers` in `run(program, handlers)` selects the category |
| `effect.dispatch = by_tag` | dispatch via `handlers.fetch(tag)` |
| `io.representation = tagged_effect` / `no_opaque_thunk` | IO is `Effect` data (tag/payload inspectable) |
| `beryl.namespace = separate_namespace` | `Darkcore::Ok` / `Err` kept in a separate namespace |
| `lang.ruby_min in [3.2, 3.3, 3.4]` | gemspec `required_ruby_version >= 3.2` |
