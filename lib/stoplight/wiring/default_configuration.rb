# frozen_string_literal: true

module Stoplight
  module Wiring
    # User-facing configuration interface
    class DefaultConfiguration
      # @!attribute [w] cool_off_time
      #   @return [Integer, nil] The default cool-off time in seconds.
      attr_accessor :cool_off_time

      # @!attribute [w] threshold
      #   @return [Integer, Float, nil] The default failure threshold to trip the circuit breaker.
      attr_accessor :threshold

      # @!attribute [w] recovery_threshold
      #  @return [Integer, nil] The default recovery threshold for the circuit breaker.
      attr_accessor :recovery_threshold

      # @!attribute [w] window_size
      #   @return [Integer, nil] The default size of the rolling window for failure tracking.
      attr_accessor :window_size

      # @!attribute [w] tracked_errors
      #   @return [Array<Class>, nil] The default list of errors to track.
      attr_accessor :tracked_errors

      # @!attribute [w] skipped_errors
      #   @return [Array<Class>, nil] The default list of errors to skip.
      attr_accessor :skipped_errors

      # @!attribute [w] error_notifier
      #   @return [Proc, nil] The default error notifier (callable object).
      attr_accessor :error_notifier

      # @!attribute [rw] notifiers
      #   @return [Array<Stoplight::Domain::StateTransitionNotifier>] The default list of notifiers.
      attr_accessor :notifiers

      # @!attribute [rw] data_store
      #   @return [Stoplight::Wiring::DataStore::Base] The default data store instance.
      attr_accessor :data_store

      # @!attribute [w] traffic_control
      #   @return [Stoplight::Domain::TrafficControl::Base] The traffic control strategy.
      attr_accessor :traffic_control

      # @!attribute [w] traffic_recovery
      #   @return [Stoplight::Domain::TrafficRecovery::Base] The traffic recovery strategy.
      attr_accessor :traffic_recovery

      def initialize
        # This allows users appending notifiers to the default list,
        # while still allowing them to override the default list.
        @notifiers = Default::NOTIFIERS
      end
    end
  end
end
