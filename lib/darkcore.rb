# frozen_string_literal: true

# ==================================================================
# darkcore — モナド動物園 + 単一 Effect 型 (Freer) の Ruby 移植。
#
# Python minamorl/darkcore を Ruby へ。全 IO を tagged effect 化し、
# handler 差し替えだけで圏(real IO / pure record / dry-run 等)を選ぶ。
# ==================================================================

require_relative "darkcore/version"
require_relative "darkcore/monad"     # fmap/ap を pure+bind から導出する土台
require_relative "darkcore/effect"    # 単一 Effect 型 (Freer) + トランポリン run
require_relative "darkcore/maybe"
require_relative "darkcore/result"
require_relative "darkcore/validation"
require_relative "darkcore/either"
require_relative "darkcore/state"
require_relative "darkcore/io_effects" # IO 語彙 + 圏R/圏V handler マップ
