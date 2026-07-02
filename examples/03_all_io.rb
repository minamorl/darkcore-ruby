# frozen_string_literal: true

# ==========================================================================
# 例3: すべての IO を単一 Effect 型のタグで網羅し、圏R/圏V を切り替える
#
# read も stdin も shell も全部【同格の tagged effect】= ただのデータ。
#   圏R: 本物の OS(実ファイル・実 stdin・実時刻・実乱数・実 shell)
#   圏V: 完全インメモリの仮想世界(決定的・OS 非接触)
# program を一文字も変えずに切り替わる。
#   ruby -Ilib examples/03_all_io.rb
# ==========================================================================

require_relative "../lib/darkcore"

include Darkcore::IOEffects

TMP = "/tmp/darkcore_io_all"

# あらゆる IO を1本に編んだ program(実行前・ただのデータ)
program =
  getenv("USER").bind do |user|
    now.bind do |t0|
      say("[#{t0}] hello #{user}").seq(
        write(TMP, "alpha\nbeta\n").seq(
          append(TMP, "gamma\n").seq(
            read(TMP).bind do |body|
              exists(TMP).bind do |ex|
                ask("ニックネームは? ").bind do |nick|
                  rand(1000).bind do |token|
                    shell("echo shelled-$((1+1))").bind do |shout|
                      warn("progress: 主要IOを一通り実行").seq(
                        delete(TMP).seq(
                          exists(TMP).bind do |ex2|
                            Darkcore.pure(
                              user: user, file_lines: body.split("\n"),
                              existed: ex, exists_now: ex2,
                              nick: nick, token: token, shell_out: shout.strip
                            )
                          end
                        )
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

puts "program の型: #{program.class} (実行前・ただのデータ)"
puts

puts "== 圏V: 完全インメモリの仮想世界(決定的・OS 非接触) =="
world = Darkcore::VirtualWorld.new(
  inputs: ["ゆい"],
  env: { "USER" => "virtual-user" },
  now: "12:00:00",
  rand_seq: [423],
  shell: { "echo shelled-$((1+1))" => "shelled-2\n" }
)
res_v = Darkcore.run(program, world.handlers)
puts "  => #{res_v.inspect}"
puts "  仮想 stderr: #{world.warnings.inspect}"
puts "  実行後の仮想FS: #{world.fs.inspect}"
puts

puts "== 圏R: 本物の OS(同じ program・handler だけ差し替え) =="
puts "  (stdin から1行読むので、何か入力して Enter)"
res_r = Darkcore.run(program, Darkcore::IOEffects.real_handlers)
puts "  => #{res_r.inspect}"
