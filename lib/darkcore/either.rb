# frozen_string_literal: true

module Darkcore
  # ------------------------------------------------------------------
  # Either — Left で短絡 / Right で継続(Result と同型の教科書版)。
  # ------------------------------------------------------------------
  Left = Data.define(:value) do
    include Monad

    def self.pure(x) = Right.new(x)
    def bind = self
    def fmap(&) = self
    def ap(_other) = self
    def left? = true
    def right? = false
  end

  Right = Data.define(:value) do
    include Monad

    def self.pure(x) = Right.new(x)
    def bind = yield(value)
    def left? = false
    def right? = true
  end

  module Either
    module_function

    def pure(x) = Right.new(x)
    def left(x) = Left.new(x)
    def right(x) = Right.new(x)
  end
end
