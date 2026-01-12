# frozen_string_literal: true

module Stoplight
  module Wiring
    class ConfigurationDsl
      def initialize(
        name: T.undefined,
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
        @tracked_errors = tracked_errors
        @skipped_errors = skipped_errors
        @traffic_control = traffic_control
        @traffic_recovery = traffic_recovery
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

      def tracked_errors
        value = @tracked_errors
        if value.is_a?(Undefined)
          value
        else
          Array(value)
        end
      end

      def skipped_errors
        value = @skipped_errors
        if value.is_a?(Undefined)
          value
        else
          Array(value)
        end
      end

      def traffic_control
        value = @traffic_control
        if value.is_a?(Undefined)
          value
        else
          LightFactory::TrafficControlDsl.call(value)
        end
      end

      def traffic_recovery
        value = @traffic_recovery
        if value.is_a?(Undefined)
          value
        else
          LightFactory::TrafficRecoveryDsl.call(value)
        end
      end
    end
  end
end
