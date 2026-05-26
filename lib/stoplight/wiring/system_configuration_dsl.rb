# frozen_string_literal: true

module Stoplight
  module Wiring
    class SystemConfigurationDsl
      def initialize(
        name:,
        cool_off_time: T.undefined,
        threshold: T.undefined,
        recovery_threshold: T.undefined,
        window_size: T.undefined,
        tracked_errors: T.undefined,
        skipped_errors: T.undefined,
        data_store: T.undefined,
        error_notifier: T.undefined,
        notifiers: T.undefined,
        traffic_control: T.undefined,
        traffic_recovery: T.undefined
      )
        @name = name
        @cool_off_time = cool_off_time
        @threshold = threshold
        @recovery_threshold = recovery_threshold
        @window_size = window_size
        @tracked_errors = tracked_errors.is_a?(Undefined) ? tracked_errors : Array(tracked_errors)
        @skipped_errors = skipped_errors.is_a?(Undefined) ? skipped_errors : Array(skipped_errors)
        @traffic_control = traffic_control.is_a?(Undefined) ? traffic_control : LightBuilder::TrafficControlDsl.call(traffic_control)
        @traffic_recovery = traffic_recovery.is_a?(Undefined) ? traffic_recovery : LightBuilder::TrafficRecoveryDsl.call(traffic_recovery)
        @error_notifier = error_notifier
        @data_store = data_store
        @notifiers = notifiers
      end

      def configure!(default_config)
        ConfigCompatibilityValidator.call(
          config: default_config.with(
            name:,
            cool_off_time:,
            threshold:,
            recovery_threshold:,
            window_size:,
            tracked_errors:,
            skipped_errors:,
            traffic_control:,
            traffic_recovery:,
            error_notifier:,
            data_store:,
            notifiers:
          )
        )
      end

      private

      attr_reader :name
      attr_reader :cool_off_time
      attr_reader :threshold
      attr_reader :recovery_threshold
      attr_reader :window_size
      attr_reader :error_notifier
      attr_reader :data_store
      attr_reader :notifiers
      attr_reader :tracked_errors
      attr_reader :skipped_errors
      attr_reader :traffic_control
      attr_reader :traffic_recovery
    end
  end
end
