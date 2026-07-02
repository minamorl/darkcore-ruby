# frozen_string_literal: true

module Darkcore
  # ------------------------------------------------------------------
  # Validation — Result と違い「短絡せずエラーを集める」Applicative。
  #
  # fmap は Monad から導出するが、ap は【あえて上書き】する。これは
  # 数学的事実: エラー累積の ap は bind から導出できない(bind は必ず
  # 短絡する)。Validation の本領はまさにこの累積 ap にある。
  # errors は Semigroup 結合(+)で貯める。
  # ------------------------------------------------------------------
  Success = Data.define(:value) do
    include Monad

    def self.pure(x) = Success.new(x)
    def bind = yield(value)

    def ap(other)
      case other
      when Success then other.fmap { |x| value.call(x) }
      when Failure then other # 相手のエラーを採用
      end
    end

    def success? = true
    def failure? = false
  end

  Failure = Data.define(:errors) do
    include Monad

    def self.pure(x) = Success.new(x)
    def bind = self
    def fmap(&) = self

    def ap(other)
      case other
      when Success then self
      when Failure then Failure.new(errors + other.errors) # ★エラー累積 (Semigroup)
      end
    end

    def success? = false
    def failure? = true
  end

  module Validation
    module_function

    def pure(x) = Success.new(x)
    def success(x) = Success.new(x)
    def failure(*es) = Failure.new(es.flatten)
  end
end
