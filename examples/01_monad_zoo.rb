# frozen_string_literal: true

# ==========================================================================
# 例1: モナド動物園 — Maybe / Result / Validation / State
#
# 各モナドが実装するのは pure と bind だけ。fmap/ap は自動導出。
# 合成はすべてメソッド名(bind/fmap/ap)で行い、演算子は使わない。
#   ruby -Ilib examples/01_monad_zoo.rb
# ==========================================================================

require_relative "../lib/darkcore"

include Darkcore

puts "== Maybe: nil 安全なチェーン =="
puts Maybe.from_nil({ age: 30 })
         .bind { |u| Maybe.from_nil(u[:age]) }
         .fmap { |age| age * 2 }
         .inspect                                   # Just(60)
puts Maybe.from_nil({})
         .bind { |u| Maybe.from_nil(u[:age]) }      # ここで Nothing
         .fmap { |age| age * 2 }
         .inspect                                   # Nothing
puts

puts "== Result: 失敗理由を持って短絡 =="
def parse_int(s) = Result.try { Integer(s) }
def positive(n) = n.positive? ? Result.ok(n) : Result.err("must be > 0: #{n}")

puts parse_int("21").bind { |n| positive(n) }.fmap { |n| n + 1 }.inspect  # Ok(22)
puts parse_int("xx").bind { |n| positive(n) }.inspect                     # Err(...)
puts parse_int("-5").bind { |n| positive(n) }.inspect                     # Err("must be > 0: -5")
puts

puts "== Validation: 短絡せずエラーを全部集める =="
V = Darkcore::Validation
def check_name(u)  = u[:name].to_s.empty? ? V.failure("name empty") : V.success(u[:name])
def check_age(u)   = u[:age].is_a?(Integer) && u[:age] >= 0 ? V.success(u[:age]) : V.failure("age invalid")
def check_email(u) = u[:email].to_s.include?("@") ? V.success(u[:email]) : V.failure("email invalid")

def build_user(u)
  ctor = ->(name) { ->(age) { ->(email) { { name: name, age: age, email: email } } } }
  V.success(ctor).ap(check_name(u)).ap(check_age(u)).ap(check_email(u))
end

puts build_user(name: "minamorl", age: 30, email: "m@example.com").inspect
puts build_user(name: "", age: -1, email: "nope").inspect   # 3つのエラーが全部出る
puts

puts "== State: カウンタを畳む =="
program = Darkcore::State.modify { |s| s + 1 }
                        .bind { Darkcore::State.modify { |s| s + 10 } }
                        .bind { Darkcore::State.get }
                        .fmap { |s| "counter = #{s}" }
value, final = program.run(0)
puts value            # counter = 11
puts "final=#{final}" # final=11
