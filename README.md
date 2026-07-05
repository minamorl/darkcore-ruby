# darkcore

[![ci](https://github.com/minamorl/darkcore-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/minamorl/darkcore-ruby/actions/workflows/ci.yml)
![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.2-CC342D?logo=ruby&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue)

モナド動物園 + **単一 Effect 型 (Freer monad)** の Ruby 実装。
Python [minamorl/darkcore](https://github.com/minamorl/darkcore) の移植。

全ノードを tagged な作用 1 種類で表し、IO はサンク(不透明クロージャ)ではなく
**検査・差し替え可能な tagged effect(ただのデータ)** として持つ。
同一 program を書き換えず **handler マップを差し替えるだけ** で
real IO / pure record / dry-run などの「圏」を選ぶ。
インタプリタは **トランポリン(反復)** で走るので、深い作用木でもスタックを食わない。

演算子オーバーロードは一切使わない。合成はすべてメソッド名 (`bind` / `fmap` / `ap`) で行う。

## 要件

Ruby >= 3.2

## インストール

```ruby
# Gemfile
gem "darkcore"
```

## 単一 Effect 型 (Freer)

```ruby
require "darkcore"

# 作用の語彙 — ただのタグ生成。ここでは一切 IO が起きない。
def say(m) = Darkcore.op(:say, m)
def ask(q) = Darkcore.op(:ask, q)

# program = 作用の木(実行前のただのデータ)
program =
  say("お名前は？").seq(
    ask(:name).bind { |name| Darkcore.pure("hello #{name}") }
  )

# 圏を handler マップで選ぶ — program は不変
real   = { say: ->(m) { puts m; nil }, ask: ->(_) { $stdin.gets.chomp } }
record = { say: ->(m) { nil },         ask: ->(_) { "TEST" } }

Darkcore.run(program, record) # => "hello TEST"  (OS 非接触・決定的)
```

`pure` は「継続を持たない閉じた作用」= `:pure` タグ。`bind` は圏固有の演算を
一切埋め込まない **ただの構造の接ぎ木**。演算(各圏の algebra)が現れてよいのは
`fold` の `on_return` と、作用タグごとの `handler` の2箇所だけ。

```ruby
Darkcore.fold(program, on_return: ->(x) { x.upcase }, handlers: record)
# => "HELLO TEST"
```

## IO を全部 tagged effect にする(圏R / 圏V)

```ruby
include Darkcore::IOEffects   # say/ask/read/write/append/delete/exists/list_dir/getenv/now/rand/shell

program =
  read("/tmp/x").bind { |body| say(body.upcase) }

# 圏R: 本物の OS
Darkcore.run(program, Darkcore::IOEffects.real_handlers)

# 圏V: 完全インメモリの仮想世界(モック不要・決定的)
world = Darkcore::VirtualWorld.new(files: { "/tmp/x" => "hi\n" })
Darkcore.run(program, world.handlers)
world.outputs # => ["HI\n"]
```

## モナド動物園

`Maybe` (`Just`/`Nothing`)、`Result` (`Darkcore::Ok`/`Darkcore::Err`)、
`Validation` (`Success`/`Failure`)、`Either` (`Left`/`Right`)、`State`。
各モナドが書くのは **`pure` と `bind` だけ**。`fmap`/`ap` は共通の `Monad`
ミックスインが自動導出する。

```ruby
include Darkcore

# Result: 失敗理由を持って短絡
Result.try { Integer("21") }.bind { |n| Result.ok(n + 1) }  # => Ok(22)

# Validation: 短絡せずエラーを全部集める(ap は累積)
V = Darkcore::Validation
V.success(->(a) { ->(b) { [a, b] } })
 .ap(V.failure("e1"))
 .ap(V.failure("e2"))  # => Failure(["e1", "e2"])
```

> **注**: `Validation#ap` だけは `Monad` の導出を意図的に上書きしている。
> エラー累積の applicative は原理的に monad の `bind` から導出できない
> (`bind` は必ず短絡する)ため。これが Validation の存在意義。

`Darkcore::Ok`/`Err` は `Beryl::Ok`/`Err` と名前空間を分離している。

## examples

```
ruby -Ilib examples/01_monad_zoo.rb        # Maybe/Result/Validation/State
ruby -Ilib examples/02_three_categories.rb # 同一 program を3圏で実行
ruby -Ilib examples/03_all_io.rb           # 全 IO タグを圏R/圏V で
ruby -Ilib examples/04_log_analysis.rb     # IO 作用と純粋計算の分離
```

## テスト

```
bundle exec rspec
```

Effect / Maybe / Result / Validation / Either / State の monad 則、トランポリンが
10 万ノードの作用木で SystemStackError を出さないこと、演算子オーバーロードが
存在しないこと、圏V での決定的 IO テストを含む。

## spec 準拠

本 gem は `spec-system/pins/domains/darkcore.spec` の振る舞いロックに準拠する。

| pin | 実装 |
| --- | --- |
| `core.effect.node = single_tagged` | 全ノードが `Effect(tag, payload, k)` の1種類 (`lib/darkcore/effect.rb`) |
| `core.pure.encoding = closed_effect` | `pure` = `:pure` タグ + `k=nil` の閉じた作用 |
| `core.bind.free` | `bind` は継続を接ぐだけ。圏固有の演算を持たない |
| `core.algebra.site in [handler, on_return]` | 演算は `fold` の `on_return` と tag ごとの `handler` のみ |
| `api.no_operator_overload` | 演算子未定義。合成は `bind`/`fmap`/`ap` |
| `api.bind_name = method_bind` | bind は `bind` メソッド |
| `api.derive.from in [pure, bind]` | `Monad` が `fmap`/`ap` を `pure`+`bind` から導出 |
| `run.strategy = trampoline` / `no_naive_recursion` | `fold`/`run` は `loop`(反復)実行 |
| `category.selection = handler_map` | `run(program, handlers)` の handlers 差し替えで圏を選ぶ |
| `effect.dispatch = by_tag` | `handlers.fetch(tag)` でディスパッチ |
| `io.representation = tagged_effect` / `no_opaque_thunk` | IO は `Effect` データ(tag/payload 検査可) |
| `beryl.namespace = separate_namespace` | `Darkcore::Ok`/`Err` を名前空間分離 |
| `lang.ruby_min in [3.2, 3.3, 3.4]` | gemspec `required_ruby_version >= 3.2` |

## License

MIT
