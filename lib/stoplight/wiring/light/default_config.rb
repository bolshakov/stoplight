# frozen_string_literal: true

module Stoplight
  module Wiring
    module Light
      # Provides default settings for the Stoplight library.
      # @api private
      DefaultConfig = Domain::Config.new(
        name: "PROTITYPE",
        cool_off_time: Default::COOL_OFF_TIME,
        threshold: Default::THRESHOLD,
        recovery_threshold: Default::RECOVERY_THRESHOLD,
        window_size: Default::WINDOW_SIZE,
        tracked_errors: Default::TRACKED_ERRORS,
        skipped_errors: Default::SKIPPED_ERRORS
      )
    end
  end
end
