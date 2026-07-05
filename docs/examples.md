# Examples and Tests

## Runnable examples

```
ruby -Ilib examples/01_monad_zoo.rb        # Maybe / Result / Validation / State
ruby -Ilib examples/02_three_categories.rb # the same program run in 3 categories
ruby -Ilib examples/03_all_io.rb           # every IO tag under Category R / V
ruby -Ilib examples/04_log_analysis.rb     # separating IO effects from pure computation
```

`04_log_analysis.rb` is the one to read if you want the design punchline: only
`read` / `write` / `log` live on the effect tree; the actual string work
(`grep`, `split`, `tally`, `scan`) is ordinary Ruby in the `bind` blocks. darkcore
owns only the IO boundary and leaves the computation to plain Ruby, so the pure
functions stay unit-testable with no file at all.

## Tests

```
bundle exec rspec
```

The suite covers the monad laws for Effect / Maybe / Result / Validation /
Either / State, proves the trampoline does not raise `SystemStackError` on a
100k-node effect tree, asserts that no operator overloading exists, and includes
deterministic IO tests under Category V.
