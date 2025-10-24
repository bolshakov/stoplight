# frozen_string_literal: true

module Stoplight
  module Wiring
    # User-facing configuration interface
    class DefaultConfiguration
      # @!attribute [w] cool_off_time
      #   @return [Integer, nil] The default cool-off time in seconds.
      attr_writer :cool_off_time

      # @!attribute [w] threshold
      #   @return [Integer, Float, nil] The default failure threshold to trip the circuit breaker.
      attr_writer :threshold

      # @!attribute [w] recovery_threshold
      #  @return [Integer, nil] The default recovery threshold for the circuit breaker.
      attr_writer :recovery_threshold

      # @!attribute [w] window_size
      #   @return [Integer, nil] The default size of the rolling window for failure tracking.
      attr_writer :window_size

      # @!attribute [w] tracked_errors
      #   @return [Array<Class>, nil] The default list of errors to track.
      attr_writer :tracked_errors

      # @!attribute [w] skipped_errors
      #   @return [Array<Class>, nil] The default list of errors to skip.
      attr_writer :skipped_errors

      # @!attribute [w] error_notifier
      #   @return [Proc, nil] The default error notifier (callable object).
      attr_writer :error_notifier

      # @!attribute [rw] notifiers
      #   @return [Array<Stoplight::Domain::StateTransitionNotifier>] The default list of notifiers.
      attr_accessor :notifiers

      # @!attribute [rw] data_store
      #   @return [Stoplight::DataStore::Base] The default data store instance.
      attr_accessor :data_store

      # @!attribute [w] traffic_control
      #   @return [Stoplight::Domain::TrafficControl::Base] The traffic control strategy.
      attr_writer :traffic_control

      # @!attribute [w] traffic_recovery
      #   @return [Stoplight::Domain::TrafficRecovery::Base] The traffic recovery strategy.
      attr_writer :traffic_recovery

      def initialize
        # This allows users appending notifiers to the default list,
        # while still allowing them to override the default list.
        @notifiers = Default::NOTIFIERS
      end

      # Converts the user-defined configuration to a hash.
      #
      # @return [Hash] A hash representation of the configuration, excluding nil values.
      # @api private
      def to_h
        {
          cool_off_time: @cool_off_time,
          threshold: @threshold,
          recovery_threshold: @recovery_threshold,
          window_size: @window_size,
          tracked_errors: @tracked_errors,
          skipped_errors: @skipped_errors,
          data_store: @data_store,
          error_notifier: @error_notifier,
          notifiers: @notifiers,
          traffic_control: @traffic_control,
          traffic_recovery: @traffic_recovery
        }.compact
      end
    end
  end
end
