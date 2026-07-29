# frozen_string_literal: true

module Darkcore
  # ==================================================================
  # Effect — 単一 Effect 型 (Freer monad)
  #
  # Pure/Impure の二分法を廃し、全ノードを tagged な作用 1 種類で表す。
  # (spec: core.effect.node = single_tagged)
  #
  #   Effect(tag, payload, k)
  #     tag     : どの圏(handler)で解釈されるかの印。ディスパッチキー。
  #     payload : 作用への入力(検査・差し替え可能なただのデータ)。
  #     k       : 継続。作用の結果を受け取り「次の Effect」を返す関数。
  #
  # 従来の pure / return は「継続を持たない閉じた作用」= :pure タグとして
  # 畳み込む。(spec: core.pure.encoding = closed_effect)
  #
  # IO はサンク(不透明クロージャ)ではなく、この tagged effect(検査・
  # 差し替え可能なデータ)として持つ。(spec: io.representation = tagged_effect)
  # ==================================================================
  Effect = Data.define(:tag, :payload, :k) do
    include Monad

    # 閉じた作用(継続なし)= 従来の pure / return。
    def self.pure(x) = new(:pure, x, nil)

    # 継続を持たない :pure ノードか?(= 実行の終端)
    def closed? = tag == :pure && k.nil?

    # ----------------------------------------------------------------
    # bind — 圏固有の演算(category algebra)をひとつも埋め込まない。
    # ただの構造の接ぎ木(free = 意味を持たない)。
    # (spec: core.bind.free / core.algebra.site in [handler, on_return])
    # ----------------------------------------------------------------
    def bind(&f)
      if closed?
        # 閉じた点なら、そのまま次の作用へ継続を接ぐだけ。
        f.call(payload)
      else
        # 実行せず木を伸ばす。継続の内側に f を差し込むだけ。
        Effect.new(tag, payload, ->(x) { k.call(x).bind(&f) })
      end
    end

    # 逐次実行(前の結果を捨てて次の作用へ)。bind の特例。
    def seq(nxt) = bind { |_| nxt }
  end

  # ==================================================================
  # step の戻り値 — 作用木が「いまどこにいるか」を表す検査可能なデータ。
  #
  #   Done(value)                    終端。閉じた :pure 作用に到達した。
  #   Pending(tag, payload, resume)  次に解釈すべき作用。resume に結果を
  #                                  渡すと続きの Effect 木が返る。
  #
  # Pending は作用を実行していない。tag も payload も handler へ渡す前の
  # ただのデータなので、走らせずに覗ける。(spec: io.no_opaque_thunk)
  # ==================================================================
  Done = Data.define(:value)
  Pending = Data.define(:tag, :payload, :resume)

  module_function

  # ----------------------------------------------------------------
  # step — 作用木を 1 歩だけ進める (fold の 1 ステップ版)。
  #
  # fold は終端まで走り切るので、作用の途中で止めて後で再開することが
  # できない。step は解釈を一切せず、いま何を待っているかを Done /
  # Pending として返すだけなので、呼び手の側がスケジューラになれる:
  #
  #   state = Darkcore.step(prog)
  #   case state
  #   when Darkcore::Done    then state.value
  #   when Darkcore::Pending then state.resume.call(handle(state.tag, state.payload))
  #   end
  #
  # これで IO 待ちで他のファイバへ譲る / 止まっている作用を覗く といった
  # ことが handler を書かずにできる。fold は step の上に載っている。
  # ----------------------------------------------------------------
  def step(prog)
    return Done.new(prog.payload) if prog.tag == :pure && prog.k.nil?

    Pending.new(prog.tag, prog.payload, prog.k)
  end

  # 閉じた作用 = pure / return。
  def pure(x) = Effect.pure(x)

  # 別名(プロトタイプ由来の慣習)。
  def ret(x) = Effect.pure(x)

  # ----------------------------------------------------------------
  # op / perform — 作用の smart constructor。
  # tag を投げて結果 x を受け取る(継続は「値をそのまま返す」で初期化)。
  # ここでは一切副作用が起きない。返るのは検査可能な純粋データ。
  # ----------------------------------------------------------------
  def op(tag, payload = nil)
    raise ArgumentError, ":pure は予約タグ(閉じた作用)" if tag == :pure

    Effect.new(tag, payload, ->(x) { Effect.pure(x) })
  end
  alias_method :perform, :op
  module_function :perform

  # ----------------------------------------------------------------
  # fold — 作用木の畳み込み(インタプリタの本体)。
  #
  #   on_return : 終端の :pure 値を最終結果へ写す関数(圏の algebra)。
  #   handlers  : { tag => ->(payload){...} } の handler マップ。
  #               tag ごとの解釈(= もう一つの algebra site)。
  #
  # 演算(各圏の algebra)が現れてよいのはこの on_return と handler だけ。
  # (spec: core.algebra.site in [handler, on_return])
  #
  # 実行は再帰ではなく反復(トランポリン = loop)。深い作用木でも
  # スタックを食わない。(spec: run.strategy = trampoline /
  # run.no_naive_recursion)
  #
  # 作用は tag でディスパッチする。(spec: effect.dispatch = by_tag)
  #
  # 本体は step の反復。「1 歩進める」と「走り切る」を分けてあるので、
  # 途中で止めたい呼び手は step を直に回せばよい。
  # ----------------------------------------------------------------
  def fold(prog, on_return:, handlers:)
    cur = prog
    loop do
      state = step(cur)
      return on_return.call(state.value) if state.is_a?(Done)

      h = handlers.fetch(state.tag) { raise KeyError, "no handler for effect: #{state.tag.inspect}" }
      cur = state.resume.call(h.call(state.payload))
    end
  end

  # run — fold の素直な特化(on_return = 恒等)。
  # 同一 program を書き換えず handlers を差し替えるだけで圏を選ぶ。
  # (spec: category.selection = handler_map)
  def run(prog, handlers)
    fold(prog, on_return: ->(x) { x }, handlers: handlers)
  end
end
