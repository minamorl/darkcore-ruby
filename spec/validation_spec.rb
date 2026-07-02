# frozen_string_literal: true

RSpec.describe "Darkcore Validation" do
  V = Darkcore::Validation

  describe "monad laws (bind は短絡する)" do
    let(:f) { ->(x) { Darkcore::Success.new(x * 2) } }
    let(:g) { ->(x) { Darkcore::Success.new(x + 1) } }

    it "left identity" do
      expect(V.pure(5).bind(&f)).to eq(f.call(5))
    end

    it "right identity" do
      m = Darkcore::Success.new(5)
      expect(m.bind { |x| V.pure(x) }).to eq(m)
    end

    it "associativity" do
      m = Darkcore::Success.new(5)
      expect(m.bind(&f).bind(&g)).to eq(m.bind { |x| f.call(x).bind(&g) })
    end
  end

  describe "ap はエラーを累積する (Applicative, 短絡しない)" do
    def check_name(u) = u[:name].to_s.empty? ? V.failure("name empty") : V.success(u[:name])
    def check_age(u)  = u[:age].is_a?(Integer) && u[:age] >= 0 ? V.success(u[:age]) : V.failure("age invalid")
    def check_email(u) = u[:email].to_s.include?("@") ? V.success(u[:email]) : V.failure("email invalid")

    def build(u)
      ctor = ->(name) { ->(age) { ->(email) { { name: name, age: age, email: email } } } }
      V.success(ctor).ap(check_name(u)).ap(check_age(u)).ap(check_email(u))
    end

    it "全て正しければ Success" do
      out = build(name: "minamorl", age: 30, email: "m@example.com")
      expect(out).to eq(Darkcore::Success.new({ name: "minamorl", age: 30, email: "m@example.com" }))
    end

    it "複数エラーを全部集める (短絡しない)" do
      out = build(name: "", age: -1, email: "nope")
      expect(out.failure?).to be(true)
      expect(out.errors).to eq(["name empty", "age invalid", "email invalid"])
    end
  end

  describe "設計上の例外: ap のみ上書き, fmap は導出" do
    it "Success#fmap の owner は Monad(導出)" do
      expect(Darkcore::Success.instance_method(:fmap).owner).to eq(Darkcore::Monad)
    end

    it "Success#ap の owner は Success 自身(累積のため意図的に上書き)" do
      expect(Darkcore::Success.instance_method(:ap).owner).to eq(Darkcore::Success)
    end
  end
end
