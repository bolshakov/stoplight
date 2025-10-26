# frozen_string_literal: true

module Stoplight
  module Wiring
    module Light
      # Provides default settings for the Stoplight library.
      # @api private
      DefaultConfig = Stoplight::Domain::Config.empty.with(
        cool_off_time: Stoplight::Default::COOL_OFF_TIME,
        threshold: Stoplight::Default::THRESHOLD,
        recovery_threshold: Stoplight::Default::RECOVERY_THRESHOLD,
        window_size: Stoplight::Default::WINDOW_SIZE,
        tracked_errors: Stoplight::Default::TRACKED_ERRORS,
        skipped_errors: Stoplight::Default::SKIPPED_ERRORS
      )
    end
  end
end
