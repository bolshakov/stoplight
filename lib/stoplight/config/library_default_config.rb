# frozen_string_literal: true

module Stoplight
  module Config
    # Provides default settings for the Stoplight library.
    # @api private
    class LibraryDefaultConfig
      DEFAULT_SETTINGS = {
        cool_off_time: Stoplight::Default::COOL_OFF_TIME,
        data_store: Stoplight::Default::DATA_STORE,
        error_notifier: Stoplight::Default::ERROR_NOTIFIER,
        notifiers: Stoplight::Default::NOTIFIERS,
        threshold: Stoplight::Default::THRESHOLD,
        window_size: Stoplight::Default::WINDOW_SIZE,
        tracked_errors: Stoplight::Default::TRACKED_ERRORS,
        skipped_errors: Stoplight::Default::SKIPPED_ERRORS,
        traffic_control: Stoplight::Default::TRAFFIC_CONTROL,
        traffic_recovery: Stoplight::Default::TRAFFIC_RECOVERY
      }.freeze
      private_constant :DEFAULT_SETTINGS

      # Returns library default settings.
      # @return [Hash]
      def to_h
        DEFAULT_SETTINGS
      end
    end
  end
end
