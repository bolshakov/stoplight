# frozen_string_literal: true

module Stoplight
  module Wiring
    module Light
      SystemConfig = DefaultConfig.with(
        recovery_threshold: 3
      )
    end
  end
end
