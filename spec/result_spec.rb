# frozen_string_literal: true

RSpec.describe "Darkcore Result" do
  let(:f) { ->(x) { Darkcore::Ok.new(x * 2) } }
  let(:g) { ->(x) { Darkcore::Ok.new(x + 1) } }

  describe "monad laws" do
    it "left identity" do
      expect(Darkcore::Result.pure(5).bind(&f)).to eq(f.call(5))
    end

    it "right identity" do
      m = Darkcore::Ok.new(5)
      expect(m.bind { |x| Darkcore::Result.pure(x) }).to eq(m)
    end

    it "associativity" do
      m = Darkcore::Ok.new(5)
      expect(m.bind(&f).bind(&g)).to eq(m.bind { |x| f.call(x).bind(&g) })
    end
  end

  describe "短絡と理由の保持" do
    it "Err はエラーを保持して以降を素通り" do
      result = Darkcore::Result.err("boom").bind(&f).fmap { |x| x + 1 }
      expect(result).to eq(Darkcore::Err.new("boom"))
      expect(result.err?).to be(true)
    end

    it "try は例外を Err に畳む" do
      ok = Darkcore::Result.try { Integer("21") }
      ng = Darkcore::Result.try { Integer("xx") }
      expect(ok).to eq(Darkcore::Ok.new(21))
      expect(ng.err?).to be(true)
    end
  end

  describe "beryl.namespace = separate_namespace" do
    it "Darkcore::Ok/Err は Darkcore 名前空間に閉じている" do
      expect(Darkcore::Ok.name).to eq("Darkcore::Ok")
      expect(Darkcore::Err.name).to eq("Darkcore::Err")
    end

    it "Beryl::Ok/Err とは別クラス(グローバル Ok を汚さない)" do
      expect(defined?(::Ok)).to be_nil
      expect(defined?(Darkcore::Ok)).to eq("constant")
    end
  end
end
