# frozen_string_literal: true

module Darkcore
  # ------------------------------------------------------------------
  # Maybe — 失敗を「無」で表す (Nothing で短絡)。
  # 各クラスが書くのは pure と bind だけ。fmap/ap は Monad から導出。
  # ------------------------------------------------------------------
  Just = Data.define(:value) do
    include Monad

    def self.pure(x) = Just.new(x)
    def bind = yield(value)
    def nothing? = false
    def just? = true
  end

  Nothing = Data.define do
    include Monad

    def self.pure(x) = Just.new(x)

    # 中身が無いので次へ進まない = 短絡。
    def bind = self
    def fmap(&) = self
    def ap(_other) = self
    def nothing? = true
    def just? = false
  end

  module Maybe
    module_function

    def pure(x) = Just.new(x)
    def just(x) = Just.new(x)
    def nothing = Nothing.new
    def from_nil(x) = x.nil? ? Nothing.new : Just.new(x)
  end
end
