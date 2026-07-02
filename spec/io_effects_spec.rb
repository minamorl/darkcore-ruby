# frozen_string_literal: true

# spec: io.representation = tagged_effect / category.selection = handler_map
# 圏V(インメモリ仮想世界)を使えば OS 非接触・モック無しで決定的にテストできる。
RSpec.describe "Darkcore IOEffects (圏V で決定的テスト)" do
  include Darkcore::IOEffects

  # プログラム = 作用の木。IO は起きない、ただのデータ。
  def program
    getenv("USER").bind do |user|
      now.bind do |t|
        say("[#{t}] hi #{user}").seq(
          write("/tmp/x", "alpha\n").seq(
            append("/tmp/x", "beta\n").seq(
              read("/tmp/x").bind do |body|
                exists("/tmp/x").bind do |ex|
                  ask("nick? ").bind do |nick|
                    rand(1000).bind do |token|
                      shell("echo hi").bind do |sh|
                        Darkcore.pure(
                          user: user, lines: body.split("\n"), existed: ex,
                          nick: nick, token: token, shell: sh.strip
                        )
                      end
                    end
                  end
                end
              end
            )
          )
        )
      end
    end
  end

  it "作用の smart constructor は不透明サンクでなく検査可能なデータを返す" do
    e = read("/etc/passwd")
    expect(e).to be_a(Darkcore::Effect)
    expect(e.tag).to eq(:read)
    expect(e.payload).to eq("/etc/passwd")
  end

  it "圏V で program を一文字も変えず決定的に実行できる" do
    world = Darkcore::VirtualWorld.new(
      inputs: ["yui"],
      env: { "USER" => "virtual-user" },
      now: "12:00",
      rand_seq: [423],
      shell: { "echo hi" => "shelled\n" }
    )

    result = Darkcore.run(program, world.handlers)

    expect(result).to eq(
      user: "virtual-user",
      lines: %w[alpha beta],
      existed: true,
      nick: "yui",
      token: 423,
      shell: "shelled"
    )
  end

  it "圏V は副作用を記録する(仮想FS・出力ログ)" do
    world = Darkcore::VirtualWorld.new(
      inputs: ["yui"], env: { "USER" => "u" }, now: "0", rand_seq: [1],
      shell: { "echo hi" => "" }
    )
    Darkcore.run(program, world.handlers)

    expect(world.fs["/tmp/x"]).to eq("alpha\nbeta\n")
    expect(world.outputs).to eq(["[0] hi u"])
    expect(world.log.map(&:first)).to include(:say, :write, :append, :read)
  end

  it "handler マップ差し替えだけで別の圏になる (dry-run 相当)" do
    plan = []
    dry = Darkcore::IOEffects.real_handlers.merge(
      say:    ->(m) { plan << "SAY #{m}"; nil },
      getenv: ->(_) { "U" },
      now:    ->(_) { "T" },
      write:  ->((p, _)) { plan << "WRITE #{p}"; nil },
      append: ->((p, _)) { plan << "APPEND #{p}"; nil },
      read:   ->(_) { "alpha\nbeta\n" },
      exists: ->(_) { true },
      ask:    ->(_) { "n" },
      rand:   ->(_) { 0 },
      shell:  ->(_) { "" }
    )
    Darkcore.run(program, dry)
    expect(plan).to eq(["SAY [T] hi U", "WRITE /tmp/x", "APPEND /tmp/x"])
  end
end
