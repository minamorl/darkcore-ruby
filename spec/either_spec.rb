# frozen_string_literal: true

RSpec.describe "Darkcore Either" do
  let(:f) { ->(x) { Darkcore::Right.new(x * 2) } }
  let(:g) { ->(x) { Darkcore::Right.new(x + 1) } }

  describe "monad laws" do
    it "left identity" do
      expect(Darkcore::Either.pure(5).bind(&f)).to eq(f.call(5))
    end

    it "right identity" do
      m = Darkcore::Right.new(5)
      expect(m.bind { |x| Darkcore::Either.pure(x) }).to eq(m)
    end

    it "associativity" do
      m = Darkcore::Right.new(5)
      expect(m.bind(&f).bind(&g)).to eq(m.bind { |x| f.call(x).bind(&g) })
    end
  end

  it "Left は短絡する" do
    result = Darkcore::Either.left("stop").bind(&f).fmap { |x| x + 1 }
    expect(result).to eq(Darkcore::Left.new("stop"))
    expect(result.left?).to be(true)
  end

  it "Right は継続する" do
    result = Darkcore::Either.right(10).bind(&f).fmap { |x| x + 1 }
    expect(result).to eq(Darkcore::Right.new(21))
  end
end
