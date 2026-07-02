# frozen_string_literal: true

RSpec.describe "Darkcore State" do
  S = Darkcore::State

  describe "monad laws (behavioral: run(s) の結果で比較)" do
    let(:f) { ->(x) { S.new(->(s) { [x * 2, s + 1] }) } }
    let(:g) { ->(x) { S.new(->(s) { [x + 1, s + 10] }) } }

    it "left identity" do
      expect(S.pure(5).bind(&f).run(0)).to eq(f.call(5).run(0))
    end

    it "right identity" do
      m = S.new(->(s) { [s * 2, s + 1] })
      expect(m.bind { |x| S.pure(x) }.run(3)).to eq(m.run(3))
    end

    it "associativity" do
      m = S.new(->(s) { [s, s + 1] })
      lhs = m.bind(&f).bind(&g)
      rhs = m.bind { |x| f.call(x).bind(&g) }
      expect(lhs.run(0)).to eq(rhs.run(0))
    end
  end

  it "get/put/modify でカウンタを畳む" do
    program = S.modify { |s| s + 1 }
               .bind { S.modify { |s| s + 10 } }
               .bind { S.get }
               .fmap { |s| "counter = #{s}" }
    value, final = program.run(0)
    expect(value).to eq("counter = 11")
    expect(final).to eq(11)
  end
end
