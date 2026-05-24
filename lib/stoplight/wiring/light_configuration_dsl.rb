# frozen_string_literal: true

module Stoplight
  module Wiring
    class LightConfigurationDsl
      def initialize(
        name:,
        cool_off_time: T.undefined,
        threshold: T.undefined,
        recovery_threshold: T.undefined,
        window_size: T.undefined,
        tracked_errors: T.undefined,
        skipped_errors: T.undefined,
        traffic_control: T.undefined,
        traffic_recovery: T.undefined
      )
        @digest = [
          @name = name,
          @cool_off_time = cool_off_time,
          @threshold = threshold,
          @recovery_threshold = recovery_threshold,
          @window_size = window_size,
          @tracked_errors = tracked_errors.is_a?(Undefined) ? tracked_errors : Array(tracked_errors),
          @skipped_errors = skipped_errors.is_a?(Undefined) ? skipped_errors : Array(skipped_errors),
          @traffic_control = traffic_control.is_a?(Undefined) ? traffic_control : LightFactory::TrafficControlDsl.call(traffic_control),
          @traffic_recovery = traffic_recovery.is_a?(Undefined) ? traffic_recovery : LightFactory::TrafficRecoveryDsl.call(traffic_recovery)
        ].hash
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
            traffic_recovery:
          )
        )
      end

      attr_reader :digest

      private

      attr_reader :name
      attr_reader :cool_off_time
      attr_reader :threshold
      attr_reader :recovery_threshold
      attr_reader :window_size
      attr_reader :tracked_errors
      attr_reader :skipped_errors
      attr_reader :traffic_control
      attr_reader :traffic_recovery
    end
  end
end
