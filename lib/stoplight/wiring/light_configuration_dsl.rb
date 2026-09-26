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
        @name = name.to_s
        @id = Domain::Id.for(@name)
        @cool_off_time = cool_off_time
        @threshold = threshold
        @recovery_threshold = recovery_threshold
        @window_size = window_size
        @tracked_errors = if tracked_errors.is_a?(Undefined)
          tracked_errors
        elsif tracked_errors.is_a?(Array)
          tracked_errors
        else
          [tracked_errors]
        end
        @skipped_errors = if skipped_errors.is_a?(Undefined)
          skipped_errors
        elsif skipped_errors.is_a?(Array)
          skipped_errors
        else
          [skipped_errors]
        end
        @traffic_control = traffic_control.is_a?(Undefined) ? traffic_control : TrafficControlDsl.call(traffic_control)
        @traffic_recovery = traffic_recovery.is_a?(Undefined) ? traffic_recovery : TrafficRecoveryDsl.call(traffic_recovery)

        @digest = calculate_digest
      end

      def configure!(default_config)
        ConfigCompatibilityValidator.call(
          config: default_config.with(
            id: @id,
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

      def calculate_digest
        [
          @id,
          @cool_off_time,
          @threshold,
          @recovery_threshold,
          @window_size,
          errors_for_digest(@tracked_errors),
          errors_for_digest(@skipped_errors),
          @traffic_control,
          @traffic_recovery
        ].hash
      end

      attr_reader :name
      attr_reader :cool_off_time
      attr_reader :threshold
      attr_reader :recovery_threshold
      attr_reader :window_size
      attr_reader :tracked_errors
      attr_reader :skipped_errors
      attr_reader :traffic_control
      attr_reader :traffic_recovery

      def errors_for_digest(errors)
        if errors.is_a?(Undefined)
          errors
        else
          errors.map { |matcher| Domain::MatcherValidator.call(matcher) }
        end
      end
    end
  end
end
