# frozen_string_literal: true

# ==================================================================
# step — 作用木を 1 歩だけ進める再開可能インタプリタ。
#
# fold は終端まで走り切るので、作用の途中で「止めて後で再開する」
# ことができない。step はそこを開ける: 解釈を一切せず、いま何を
# 待っているかを Done / Pending として返すだけ。
#
# 検証したいこと:
#   1. step 自身は作用を実行しない (handler を渡していないのだから当然、
#      という状態をテストで固定する)。
#   2. Pending は tag / payload を検査可能なデータとして持つ。
#   3. resume に結果を渡すと続きの木が返り、任意の順序・タイミングで
#      再開できる (= 呼び手がスケジューラになれる)。
#   4. fold は step の反復として書けており、挙動が変わっていない。
# ==================================================================
RSpec.describe "Darkcore.step" do
  let(:program) do
    Darkcore.op(:ask, "name").bind do |name|
      Darkcore.op(:say, "hello #{name}").seq(Darkcore.pure(:done))
    end
  end

  describe "終端の見分け" do
    it "閉じた :pure 作用は Done を返す" do
      state = Darkcore.step(Darkcore.pure(42))

      expect(state).to be_a(Darkcore::Done)
      expect(state.value).to eq(42)
    end

    it "作用が残っていれば Pending を返す" do
      expect(Darkcore.step(program)).to be_a(Darkcore::Pending)
    end
  end

  describe "止まっている作用は覗ける (no_opaque_thunk)" do
    it "Pending は tag と payload をそのまま持つ" do
      state = Darkcore.step(program)

      expect(state.tag).to eq(:ask)
      expect(state.payload).to eq("name")
    end

    it "step は継続を呼ばない (だから作用は一切起きない)" do
      tripped = false
      effectful = Darkcore.op(:say, "boom").bind do |_|
        tripped = true
        Darkcore.pure(:done)
      end

      Darkcore.step(effectful)

      expect(tripped).to be(false)
    end
  end

  describe "再開" do
    it "resume に結果を渡すと続きの木が返る" do
      first = Darkcore.step(program)
      second = Darkcore.step(first.resume.call("mina"))

      expect(second.tag).to eq(:say)
      expect(second.payload).to eq("hello mina")
    end

    it "呼び手が自分のループで走らせられる (スケジューラを外から書ける)" do
      log = []
      answers = { ask: "mina", say: nil }
      cur = program

      result = loop do
        state = Darkcore.step(cur)
        break state.value if state.is_a?(Darkcore::Done)

        log << [state.tag, state.payload]
        cur = state.resume.call(answers.fetch(state.tag))
      end

      expect(result).to eq(:done)
      expect(log).to eq([[:ask, "name"], [:say, "hello mina"]])
    end

    it "同じ Pending から別の結果で再開すると別の続きになる (継続は使い捨てでない)" do
      pending_state = Darkcore.step(program)

      one = Darkcore.step(pending_state.resume.call("a"))
      two = Darkcore.step(pending_state.resume.call("b"))

      expect(one.payload).to eq("hello a")
      expect(two.payload).to eq("hello b")
    end

    it "再開を遅らせても続きは失われない (IO 待ちで譲れる)" do
      parked = Darkcore.step(program)
      Darkcore.run(Darkcore.op(:other).bind { Darkcore.pure(1) }, { other: ->(_) { 1 } })

      expect(Darkcore.step(parked.resume.call("mina")).payload).to eq("hello mina")
    end
  end

  describe "fold は step の反復として書かれている" do
    it "同じ program を fold で走らせた結果と一致する" do
      said = []
      handlers = { ask: ->(_) { "mina" }, say: ->(m) { said << m; nil } }

      expect(Darkcore.run(program, handlers)).to eq(:done)
      expect(said).to eq(["hello mina"])
    end

    it "未定義 tag は fold のときだけ落ちる (step は tag を見るだけ)" do
      expect { Darkcore.step(Darkcore.op(:missing)) }.not_to raise_error
      expect { Darkcore.run(Darkcore.op(:missing), {}) }.to raise_error(KeyError)
    end

    it "深い作用木を step のループで回してもスタックを食わない" do
      depth = 100_000
      prog = Darkcore.pure(:done)
      depth.times { prog = Darkcore.op(:tick).seq(prog) }

      count = 0
      cur = prog
      result = loop do
        state = Darkcore.step(cur)
        break state.value if state.is_a?(Darkcore::Done)

        count += 1
        cur = state.resume.call(nil)
      end

      expect(result).to eq(:done)
      expect(count).to eq(depth)
    end
  end
end
