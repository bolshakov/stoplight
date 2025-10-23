# frozen_string_literal: true

module Stoplight
  module Config
    SystemConfig = LibraryDefaultConfig.with(
      traffic_recovery: :consecutive_successes,
      recovery_threshold: 3
    )
  end
end
