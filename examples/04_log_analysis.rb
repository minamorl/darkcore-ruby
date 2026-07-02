# frozen_string_literal: true

# ==========================================================================
# 例4: ログ解析 — IO 作用と純粋計算を分離する
#
# 「ファイルを切る・検出する・集計する」の大半は *純粋計算* であって作用ではない。
#   - IO 作用 (read / write / log) だけを Effect タグに載せる
#   - grep / split / tally / scan は bind の中のただの Ruby (TextOps)
# この分離のおかげで文字列処理ロジックを実ファイル無しで単体テストできる。
#   ruby -Ilib examples/04_log_analysis.rb
# ==========================================================================

require_relative "../lib/darkcore"

# 純粋な文字列処理(作用ゼロ・全部ただの Ruby・単体テスト可能)
module TextOps
  module_function

  def grep(text, pattern)
    text.each_line.with_index(1).filter_map { |line, i| [i, line.chomp] if line =~ pattern }
  end

  def parse_log_line(line)
    date, time, level, *rest = line.split(/\s+/)
    { date: date, time: time, level: level, message: rest.join(" ") }
  end

  def count_by_level(lines)
    lines.map { |l| parse_log_line(l)[:level] }.tally
  end

  def scan_durations(text)
    text.scan(/(\d+)ms/).flatten.map(&:to_i)
  end
end

def build_report(counts, errors, parsed, durations)
  out = ["=== ログ解析レポート ===", "レベル別件数:"]
  counts.sort.each { |lvl, n| out << "  #{lvl.ljust(5)}: #{n}" }
  out << "" << "ERROR 行 (#{errors.size}件):"
  errors.each { |(no, l)| out << "  L#{no}: #{l}" }
  unless durations.empty?
    out << "" << "処理時間(ms): #{durations.inspect} max=#{durations.max}"
  end
  out.join("\n") + "\n"
end

SAMPLE = <<~LOG
  2026-07-02 10:15:01 INFO  server started on :3000
  2026-07-02 10:15:03 ERROR db connection timeout after 5000ms
  2026-07-02 10:15:04 WARN  retrying db connection (attempt 2)
  2026-07-02 10:16:22 ERROR unhandled NoMethodError in UsersController#show
  2026-07-02 10:16:30 WARN  slow query 1200ms on users.index
  2026-07-02 10:17:00 INFO  request GET /health 200 3ms
LOG

include Darkcore::IOEffects

# program = 作用の木(呼んだだけでは何も起きない)
def analyze(src_path, report_path)
  write(src_path, SAMPLE).seq(read(src_path)).bind do |text|
    # ==== ここから全部ふつうの Ruby: 切る・検出する・集計する ====
    lines     = text.lines.map(&:chomp).reject(&:empty?)
    errors    = TextOps.grep(text, /ERROR/)
    counts    = TextOps.count_by_level(lines)
    parsed    = errors.map { |(_, l)| TextOps.parse_log_line(l) }
    durations = TextOps.scan_durations(text)
    report    = build_report(counts, errors, parsed, durations)
    # ==== ここまで純粋。IO に戻る ====
    write(report_path, report)
      .seq(say("wrote #{report_path} (#{report.bytesize} bytes)"))
      .seq(Darkcore.pure(report))
  end
end

program = analyze("/tmp/darkcore_app.log", "/tmp/darkcore_report.txt")

puts "== 圏R: 本物のファイルシステムで実行 =="
report = Darkcore.run(program, Darkcore::IOEffects.real_handlers)
puts "----- レポート -----"
puts report

puts "== 圏V: OS 非接触で同じ program を検証(実ファイル不要) =="
world = Darkcore::VirtualWorld.new
Darkcore.run(program, world.handlers)
puts "仮想FS に書かれたレポートのバイト数: #{world.fs['/tmp/darkcore_report.txt'].bytesize}"
puts "作用ログ: #{world.log.map(&:first).inspect}"
puts

puts "== おまけ: 純粋関数を実ファイル無しで単体テスト =="
sample = "a\nERROR boom 900ms\nb\nERROR bad\n"
p TextOps.grep(sample, /ERROR/)
p TextOps.scan_durations(sample)
