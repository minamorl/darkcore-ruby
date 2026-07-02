# frozen_string_literal: true

module Darkcore
  # ------------------------------------------------------------------
  # Result — 失敗に理由(エラー値)を持たせる Either 系。
  #   Ok で継続 / Err で短絡。
  #
  # Darkcore::Ok/Err は Beryl::Ok/Err と【名前空間を分離】する。
  # (spec: beryl.namespace = separate_namespace)
  # ------------------------------------------------------------------
  Ok = Data.define(:value) do
    include Monad

    def self.pure(x) = Ok.new(x)
    def bind = yield(value)
    def ok? = true
    def err? = false
  end

  Err = Data.define(:error) do
    include Monad

    def self.pure(x) = Ok.new(x)

    # エラーは伝播、以降の bind を素通り(短絡)。
    def bind = self
    def fmap(&) = self
    def ap(_other) = self
    def ok? = false
    def err? = true
  end

  module Result
    module_function

    def pure(x) = Ok.new(x)
    def ok(x) = Ok.new(x)
    def err(e) = Err.new(e)

    # 例外を Result 化する典型ユーティリティ。
    def try
      Ok.new(yield)
    rescue StandardError => e
      Err.new(e.message)
    end
  end
end
