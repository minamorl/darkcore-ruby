# frozen_string_literal: true

module Darkcore
  # ------------------------------------------------------------------
  # Monad — 共通ミックスイン
  #
  # 各モナドが実装するのは pure(class method) と bind(instance) の2つだけ。
  # fmap / ap はここで pure + bind から【自動導出】する。
  # (spec: api.derive.from in [pure, bind])
  #
  # 合成はすべてメソッド名で行い、演算子は一切定義しない。
  # (spec: api.no_operator_overload / api.bind_name = method_bind)
  # ------------------------------------------------------------------
  module Monad
    # Functor: fmap は「bind して pure で包み直す」だけで導出できる。
    def fmap(&f) = bind { |x| self.class.pure(f.call(x)) }

    # Ruby 慣習の別名。中身は fmap と同一。
    def map(&f) = fmap(&f)

    # Applicative: self は「関数を包んだモナド」、other は「値を包んだモナド」。
    # ap も bind + fmap から導出する。
    def ap(other)
      bind { |f| other.fmap { |x| f.call(x) } }
    end
  end
end
