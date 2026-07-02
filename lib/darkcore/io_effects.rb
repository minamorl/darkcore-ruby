# frozen_string_literal: true

module Darkcore
  # ==================================================================
  # IOEffects — 標準 IO の語彙(smart constructor 群)。
  #
  # すべて「作用を値化」するだけで、ここでは一切 IO が起きない。
  # read も stdin も shell も全部【同格の tagged effect】= ただのデータ。
  # (spec: io.representation = tagged_effect / io.no_opaque_thunk)
  #
  # program を一文字も変えず handlers を差し替えるだけで、
  # 圏R(本物の OS)/ 圏V(インメモリ仮想世界)を切り替える。
  # (spec: category.selection = handler_map)
  # ==================================================================
  module IOEffects
    module_function

    # -- コンソール --
    def say(msg)          = Darkcore.op(:say, msg)     # 標準出力
    def warn(msg)         = Darkcore.op(:warn, msg)    # 標準エラー
    def ask(prompt = nil) = Darkcore.op(:ask, prompt)  # 標準入力(1行)

    # -- ファイル --
    def read(path)          = Darkcore.op(:read, path)
    def write(path, data)   = Darkcore.op(:write, [path, data])
    def append(path, data)  = Darkcore.op(:append, [path, data])
    def delete(path)        = Darkcore.op(:delete, path)
    def exists(path)        = Darkcore.op(:exists, path)
    def list_dir(path)      = Darkcore.op(:list_dir, path)

    # -- 環境 / システム --
    def getenv(key) = Darkcore.op(:getenv, key)
    def now         = Darkcore.op(:now)
    def rand(n)     = Darkcore.op(:rand, n)
    def shell(cmd)  = Darkcore.op(:shell, cmd)

    # ----------------------------------------------------------------
    # 圏R — 本物の OS。実ファイル・実 stdin・実時刻・実乱数・実 shell。
    # 呼ぶたびに新鮮な handler マップを返す。
    # ----------------------------------------------------------------
    def real_handlers
      {
        say:      ->(m)      { puts m; nil },
        warn:     ->(m)      { Kernel.warn(m); nil },
        ask:      ->(prompt) { print prompt if prompt; $stdout.flush; ($stdin.gets || "").chomp },
        read:     ->(p)      { File.read(p) },
        write:    ->((p, d)) { File.write(p, d); nil },
        append:   ->((p, d)) { File.open(p, "a") { |f| f.write(d) }; nil },
        delete:   ->(p)      { File.delete(p) if File.exist?(p); nil },
        exists:   ->(p)      { File.exist?(p) },
        list_dir: ->(p)      { Dir.children(p) },
        getenv:   ->(k)      { ENV[k] },
        now:      ->(_)      { Time.now },
        rand:     ->(n)      { Kernel.rand(n) },
        shell:    ->(cmd)    { `#{cmd}` }
      }
    end
  end

  # ==================================================================
  # VirtualWorld — 圏V。完全インメモリの仮想世界。
  # OS を一切触らないので決定的でモック不要のテストができる。
  # handlers を program に差し込むだけで real IO と入れ替わる。
  # ==================================================================
  class VirtualWorld
    attr_reader :fs, :outputs, :warnings, :log

    def initialize(files: {}, inputs: [], env: {}, now: nil, rand_seq: [0], shell: {})
      @fs       = files.dup       # 仮想ファイルシステム { path => contents }
      @inputs   = inputs.dup      # 仮想 stdin(1行ずつ shift)
      @env      = env             # 仮想環境変数
      @now      = now             # 固定時刻
      @rand_seq = rand_seq.dup    # 決定的「乱数」列
      @shell    = shell           # コマンド => 出力 の仮想プロセス表
      @outputs  = []              # say の記録
      @warnings = []              # warn の記録
      @log      = []              # 作用の記録 [[tag, arg], ...]
      @rand_i   = 0
    end

    def handlers
      {
        say:      ->(m)      { @outputs << m; @log << [:say, m]; nil },
        warn:     ->(m)      { @warnings << m; @log << [:warn, m]; nil },
        ask:      ->(_p)     { @log << [:ask, _p]; @inputs.shift },
        read:     ->(p)      { @log << [:read, p]; @fs.fetch(p) { raise KeyError, "vfs: no such file #{p}" } },
        write:    ->((p, d)) { @fs[p] = d; @log << [:write, p]; nil },
        append:   ->((p, d)) { @fs[p] = (@fs[p] || "") + d; @log << [:append, p]; nil },
        delete:   ->(p)      { @fs.delete(p); @log << [:delete, p]; nil },
        exists:   ->(p)      { @fs.key?(p) },
        list_dir: ->(p)      { @fs.keys.select { |k| k != p && k.start_with?("#{p}/") }.map { |k| k.sub("#{p}/", "") } },
        getenv:   ->(k)      { @env[k] },
        now:      ->(_)      { @now },
        rand:     ->(n)      { v = @rand_seq[@rand_i % @rand_seq.length]; @rand_i += 1; v % n },
        shell:    ->(cmd)    { @log << [:shell, cmd]; @shell.fetch(cmd, "") }
      }
    end
  end
end
