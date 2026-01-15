# frozen_string_literal: true

module Stoplight
  module Wiring
    # Provides default settings for the Stoplight library.
    DefaultConfig = Domain::Config.new(
      name: "DEFAULT_CONFIG",
      cool_off_time: Default::COOL_OFF_TIME,
      threshold: Default::THRESHOLD,
      recovery_threshold: Default::RECOVERY_THRESHOLD,
      window_size: Default::WINDOW_SIZE,
      tracked_errors: Default::TRACKED_ERRORS,
      skipped_errors: Default::SKIPPED_ERRORS,
      traffic_control: Default::TRAFFIC_CONTROL,
      traffic_recovery: Default::TRAFFIC_RECOVERY,
      error_notifier: Default::ERROR_NOTIFIER,
      notifiers: Default::NOTIFIERS,
      data_store: Default::DATA_STORE
    )
  end
end
