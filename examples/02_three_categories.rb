# frozen_string_literal: true

# ==========================================================================
# 例2: 同一 program を handler 差し替えだけで3つの圏で走らせる
#
# program は「作用の木(ただのデータ)」。実行はしていない。
# handler マップ(tag => 解釈)を差し替えるだけで:
#   圏1: 本物の IO  /  圏2: 純粋記録(テスト)  /  圏3: dry-run(計画のみ)
# へ、program を一文字も変えずに切り替わる。
#   ruby -Ilib examples/02_three_categories.rb
# ==========================================================================

require_relative "../lib/darkcore"

# 作用の語彙(ただのタグ生成)
def say(msg)  = Darkcore.op(:say, msg)
def ask(key)  = Darkcore.op(:ask, key)
def clock     = Darkcore.op(:clock)

# program = 実行前の純粋データ
program =
  say("お名前は？").seq(
    ask(:name).bind do |name|
      clock.bind do |t|
        say("こんにちは #{name} さん (#{t})").seq(Darkcore.pure("done:#{name}"))
      end
    end
  )

puts "program の型: #{program.class} (実行前・ただのデータ)"
puts

puts "== 圏1: 本物の IO 相当 =="
real = {
  say:   ->(m) { puts "  [SAY] #{m}"; nil },
  ask:   ->(_) { "みなもり" }, # 本来は $stdin.gets.chomp
  clock: ->(_) { "13:50" }     # 本来は Time.now
}
puts "  => #{Darkcore.run(program, real).inspect}"
puts

puts "== 圏2: 純粋記録(副作用なし・同じ program) =="
trace = []
record = {
  say:   ->(m) { trace << [:say, m]; nil },
  ask:   ->(_) { "TEST_USER" },
  clock: ->(_) { "00:00" }
}
puts "  => #{Darkcore.run(program, record).inspect}"
puts "  作用 log: #{trace.inspect}"
puts

puts "== 圏3: dry-run(計画のみ・同じ program) =="
plan = []
dry = {
  say:   ->(m) { plan << "SAY #{m}"; nil },
  ask:   ->(k) { plan << "ASK #{k}"; "<#{k}>" },
  clock: ->(_) { plan << "CLOCK"; "<t>" }
}
Darkcore.run(program, dry)
plan.each { |p| puts "  - #{p}" }
