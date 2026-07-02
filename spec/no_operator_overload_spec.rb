# frozen_string_literal: true

# spec: api.no_operator_overload — 合成に演算子オーバーロードを使わない。
# beryl 側の >>/| と衝突させないため、合成はメソッド名(bind)で行う。
RSpec.describe "api.no_operator_overload" do
  MONAD_TYPES = [
    Darkcore::Effect,
    Darkcore::Just, Darkcore::Nothing,
    Darkcore::Ok, Darkcore::Err,
    Darkcore::Success, Darkcore::Failure,
    Darkcore::Left, Darkcore::Right,
    Darkcore::State
  ].freeze

  # 合成に流用されがちな演算子。これらが定義されていないことを保証する。
  FORBIDDEN_OPERATORS = %i[>> << | & ^ + * ~ @].freeze

  MONAD_TYPES.each do |klass|
    context klass.name do
      FORBIDDEN_OPERATORS.each do |op|
        it "does not define ##{op}" do
          expect(klass.instance_methods).not_to include(op)
        end
      end

      it "合成は method_bind (bind という名前) で行う" do
        expect(klass.instance_methods).to include(:bind)
      end
    end
  end

  it "Monad ミックスイン自身も演算子を定義しない" do
    expect(Darkcore::Monad.instance_methods & FORBIDDEN_OPERATORS).to be_empty
  end

  it "グローバル空間に >> 等を生やしていない (代表: Just インスタンス)" do
    j = Darkcore::Just.new(1)
    expect(j.respond_to?(:>>)).to be(false)
    expect(j.respond_to?(:|)).to be(false)
  end
end
