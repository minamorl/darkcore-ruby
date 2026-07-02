# frozen_string_literal: true

module Darkcore
  # ------------------------------------------------------------------
  # State — s -> [a, s] を包む。run(s) で回す。
  # 書くのは pure と bind だけ。fmap/ap は Monad から導出。
  # ------------------------------------------------------------------
  State = Data.define(:run_fn) do
    include Monad

    def self.pure(x) = State.new(->(s) { [x, s] })

    def run(s) = run_fn.call(s)

    def bind(&f)
      State.new(lambda do |s|
        a, s2 = run_fn.call(s)
        f.call(a).run(s2)
      end)
    end

    def self.get = State.new(->(s) { [s, s] })
    def self.put(s2) = State.new(->(_) { [nil, s2] })
    def self.modify(&f) = State.new(->(s) { [nil, f.call(s)] })
  end
end
