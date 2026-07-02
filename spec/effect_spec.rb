# frozen_string_literal: true

RSpec.describe Darkcore::Effect do
  # Effect は継続(Proc)を内包するので構造的 == では比較できない。
  # 代わりに handler で「観測」して振る舞い的等価を確かめる。
  def observe(prog)
    log = []
    result = Darkcore.run(prog, { emit: ->(x) { log << x; x } })
    [result, log]
  end

  describe "closed_effect (pure encoding)" do
    it "pure は継続を持たない :pure タグの閉じた作用" do
      p = Darkcore.pure(42)
      expect(p.tag).to eq(:pure)
      expect(p.k).to be_nil
      expect(p.closed?).to be(true)
    end

    it "op は tag/payload を検査可能なデータとして持つ (不透明サンクではない)" do
      e = Darkcore.op(:read, "/etc/hosts")
      expect(e.tag).to eq(:read)
      expect(e.payload).to eq("/etc/hosts")
      expect(e.closed?).to be(false)
    end

    it ":pure タグの op は予約として拒否する" do
      expect { Darkcore.op(:pure, 1) }.to raise_error(ArgumentError)
    end
  end

  describe "monad laws (behavioral equivalence via interpretation)" do
    let(:m) { Darkcore.op(:emit, 3) }
    let(:f) { ->(x) { Darkcore.op(:emit, x * 2) } }
    let(:g) { ->(x) { Darkcore.op(:emit, x + 1) } }

    it "left identity: pure(a).bind(f) == f(a)" do
      a = 7
      expect(observe(Darkcore.pure(a).bind(&f))).to eq(observe(f.call(a)))
    end

    it "right identity: m.bind { pure } == m" do
      expect(observe(m.bind { |x| Darkcore.pure(x) })).to eq(observe(m))
    end

    it "associativity: (m.bind f).bind g == m.bind { f(x).bind g }" do
      lhs = m.bind(&f).bind(&g)
      rhs = m.bind { |x| f.call(x).bind(&g) }
      expect(observe(lhs)).to eq(observe(rhs))
    end
  end

  describe "handler_map で圏を選ぶ (program は不変)" do
    let(:program) do
      Darkcore::IOEffects.say("hi").seq(
        Darkcore.op(:ask, nil).bind { |name| Darkcore.pure("hello #{name}") }
      )
    end

    it "同じ program を real 相当と record 相当で解釈できる" do
      log = []
      record = {
        say: ->(m) { log << [:say, m]; nil },
        ask: ->(_) { "TEST" }
      }
      expect(Darkcore.run(program, record)).to eq("hello TEST")
      expect(log).to eq([[:say, "hi"]])

      log2 = []
      dry = {
        say: ->(m) { log2 << "SAY #{m}"; nil },
        ask: ->(_) { log2 << "ASK"; "<name>" }
      }
      expect(Darkcore.run(program, dry)).to eq("hello <name>")
      expect(log2).to eq(["SAY hi", "ASK"])
    end

    it "未定義 tag は明示的に落ちる (by_tag ディスパッチ)" do
      expect { Darkcore.run(Darkcore.op(:missing), {}) }.to raise_error(KeyError)
    end
  end

  describe "fold の on_return が終端値の algebra site" do
    it "on_return で終端 :pure 値を写せる" do
      prog = Darkcore.op(:emit, 10).bind { |x| Darkcore.pure(x) }
      out = Darkcore.fold(prog, on_return: ->(x) { x * 100 }, handlers: { emit: ->(x) { x } })
      expect(out).to eq(1000)
    end
  end

  describe "trampoline: 深い作用木でもスタックを食わない (run.strategy)" do
    it "10万ノードの逐次作用を SystemStackError なく走らせる" do
      depth = 100_000
      prog = Darkcore.pure(:done)
      depth.times { prog = Darkcore.op(:tick).seq(prog) }

      count = 0
      result = nil
      expect do
        result = Darkcore.run(prog, { tick: ->(_) { count += 1; nil } })
      end.not_to raise_error

      expect(result).to eq(:done)
      expect(count).to eq(depth)
    end
  end
end
