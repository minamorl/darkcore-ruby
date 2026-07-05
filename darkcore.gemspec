# frozen_string_literal: true

require_relative "lib/darkcore/version"

Gem::Specification.new do |spec|
  spec.name        = "darkcore"
  spec.version     = Darkcore::VERSION
  spec.authors     = ["minamorl"]
  spec.email       = ["niktseft@gmail.com"]

  spec.summary     = "モナド動物園 + 単一 Effect 型 (Freer) — handler 差し替えで圏を選ぶ"
  spec.description = <<~DESC
    Python minamorl/darkcore の Ruby 移植。全ノードを tagged な作用 1 種類
    (単一 Effect 型 = Freer monad) で表し、IO はサンクではなく検査・差し替え
    可能な tagged effect として持つ。同一 program を書き換えず handler マップ
    を差し替えるだけで real IO / pure record / dry-run 等の圏を選ぶ。
    インタプリタはトランポリン(反復)で走り、深い作用木でもスタックを食わない。
    Maybe / Result / Validation / Either / State のモナド動物園付き。
  DESC

  spec.homepage = "https://github.com/minamorl/darkcore-ruby"
  spec.license  = "MIT"

  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/releases"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir[
    "lib/**/*.rb",
    "README.md",
    "LICENSE"
  ]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rspec", "~> 3.0"
end
