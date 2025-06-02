# frozen_string_literal: true

module Stoplight
  class Light
    # A +Stoplight::Light+ configuration object.
    # @api private
    class Config
      # @!attribute [r] name
      #   @return [String]
      attr_reader :name

      # @!attribute [r] cool_off_time
      #   @return [Numeric]
      attr_reader :cool_off_time

      # @!attribute [r] data_store
      #   @return [Stoplight::DataStore::Base]
      attr_reader :data_store

      # @!attribute [r] error_notifier
      #   @return [StandardError => void]
      attr_reader :error_notifier

      # @!attribute [r] notifiers
      #   @return [Array<Stoplight::Notifier::Base>]
      attr_reader :notifiers

      # @!attribute [r] threshold
      #   @return [Numeric]
      attr_reader :threshold

      # @!attribute [r] window_size
      #   @return [Numeric]
      attr_reader :window_size

      # @!attribute [r] tracked_errors
      #   @return [Array<StandardError>]
      attr_reader :tracked_errors

      # @!attribute [r] skipped_errors
      #  @return [Array<Exception>]
      attr_reader :skipped_errors

      # @!attribute [r] traffic_control
      #  @return [Stoplight::TrafficControl::Base]
      attr_reader :traffic_control

      # @!attribute [r] traffic_recovery
      #   @return [Stoplight::TrafficRecovery::Base]
      attr_reader :traffic_recovery

      # @param name [String]
      # @param cool_off_time [Numeric]
      # @param data_store [Stoplight::DataStore::Base]
      # @param error_notifier [Proc]
      # @param notifiers [Array<Stoplight::Notifier::Base>]
      # @param threshold [Numeric]
      # @param window_size [Numeric]
      # @param tracked_errors [Array<StandardError>]
      # @param skipped_errors [Array<Exception>]
      # @param traffic_control [Stoplight::TrafficControl::Base]
      # @param traffic_recovery [Stoplight::TrafficRecovery::Base]
      def initialize(name:, cool_off_time:, data_store:, error_notifier:, notifiers:, threshold:, window_size:,
        tracked_errors:, skipped_errors:, traffic_control:, traffic_recovery:)
        @name = name
        @cool_off_time = cool_off_time.to_i
        @data_store = DataStore::FailSafe.wrap(data_store)
        @error_notifier = error_notifier
        @notifiers = notifiers.map { |notifier| Notifier::FailSafe.wrap(notifier) }
        @threshold = threshold
        @window_size = window_size
        @tracked_errors = Array(tracked_errors)
        @skipped_errors = Array(skipped_errors)
        @traffic_control = traffic_control
        @traffic_recovery = traffic_recovery
      end

      # @param other [any]
      # @return [Boolean]
      def ==(other)
        other.is_a?(self.class) && to_h == other.to_h
      end

      # @param error [Exception]
      # @return [Boolean]
      def track_error?(error)
        skip = skipped_errors.any? { |klass| klass === error }
        track = tracked_errors.any? { |klass| klass === error }

        !skip && track
      end

      # Updates the configuration with new settings and returns a new instance.
      #
      # @return [Stoplight::Light::Config]
      def with(**settings)
        self.class.new(**to_h.merge(settings))
      end

      # @return [Hash]
      def to_h
        {
          cool_off_time:,
          data_store:,
          error_notifier:,
          name:,
          notifiers:,
          threshold:,
          window_size:,
          tracked_errors:,
          skipped_errors:,
          traffic_control:,
          traffic_recovery:
        }
      end
    end
  end
end
