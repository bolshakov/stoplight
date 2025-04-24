# frozen_string_literal: true

module Stoplight
  class Light < CircuitBreaker
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

      # @param name [String]
      # @param cool_off_time [Numeric]
      # @param data_store [Stoplight::DataStore::Base]
      # @param error_notifier [Proc]
      # @param notifiers [Array<Stoplight::Notifier::Base>]
      # @param threshold [Numeric]
      # @param window_size [Numeric]
      # @param tracked_errors [Array<StandardError>]
      # @param skipped_errors [Array<Exception>]
      def initialize(name: nil, cool_off_time: nil, data_store: nil, error_notifier: nil, notifiers: nil, threshold: nil, window_size: nil,
        tracked_errors: nil, skipped_errors: nil)
        @name = name
        @cool_off_time = cool_off_time
        @data_store = DataStore::FailSafe.wrap(data_store)
        @error_notifier = error_notifier
        @notifiers = notifiers.map { |notifier| Notifier::FailSafe.wrap(notifier) }
        @threshold = threshold
        @window_size = window_size
        @tracked_errors = Array(tracked_errors)
        @skipped_errors = Set[*skipped_errors, *Stoplight::Default::SKIPPED_ERRORS].to_a
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

      # @param number_of_errors [Numeric]
      # @return [Boolean]
      def threshold_exceeded?(number_of_errors)
        number_of_errors == threshold
      end

      # @param number_of_errors [Numeric]
      # @return [Boolean]
      def below_threshold?(number_of_errors)
        number_of_errors < threshold
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
          skipped_errors:
        }
      end
    end
  end
end
