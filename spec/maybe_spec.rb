# frozen_string_literal: true

RSpec.describe "Darkcore Maybe" do
  include Darkcore

  let(:f) { ->(x) { Darkcore::Just.new(x * 2) } }
  let(:g) { ->(x) { Darkcore::Just.new(x + 1) } }

  describe "monad laws (structural equality: Data の値等価)" do
    it "left identity" do
      expect(Darkcore::Maybe.pure(5).bind(&f)).to eq(f.call(5))
    end

    it "right identity" do
      m = Darkcore::Just.new(5)
      expect(m.bind { |x| Darkcore::Maybe.pure(x) }).to eq(m)
    end

    it "associativity" do
      m = Darkcore::Just.new(5)
      expect(m.bind(&f).bind(&g)).to eq(m.bind { |x| f.call(x).bind(&g) })
    end
  end

  describe "短絡" do
    it "Nothing は bind/fmap を素通りする" do
      result = Darkcore::Maybe.from_nil(nil).bind(&f).fmap { |x| x + 100 }
      expect(result).to eq(Darkcore::Nothing.new)
      expect(result.nothing?).to be(true)
    end

    it "Just はチェーンを継続する" do
      result = Darkcore::Maybe.from_nil({ age: 30 })
                             .bind { |u| Darkcore::Maybe.from_nil(u[:age]) }
                             .fmap { |age| age * 2 }
      expect(result).to eq(Darkcore::Just.new(60))
    end
  end

  describe "api.derive.from: fmap/ap は Monad ミックスインからの導出" do
    it "Just#fmap の owner は Darkcore::Monad" do
      expect(Darkcore::Just.instance_method(:fmap).owner).to eq(Darkcore::Monad)
    end

    it "Just#ap の owner は Darkcore::Monad" do
      expect(Darkcore::Just.instance_method(:ap).owner).to eq(Darkcore::Monad)
    end
  end
end
