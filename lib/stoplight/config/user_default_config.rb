# frozen_string_literal: true

require "forwardable"

module Stoplight
  module Config
    # Represents user-defined default configuration for Stoplight.
    #
    # This class allows users to define default settings for various Stoplight
    # parameters, such as cool-off time, data store, error notifier, and more.
    #
    class UserDefaultConfig
      extend Forwardable

      # @!attribute [w] cool_off_time
      #   @return [Integer, nil] The default cool-off time in seconds.
      attr_writer :cool_off_time

      # @!attribute [w] error_notifier
      #   @return [Proc, nil] The default error notifier (callable object).
      attr_writer :error_notifier

      # @!attribute [r] notifiers
      #   @return [Array<Stoplight::Notifier::Base>] The default list of notifiers.
      attr_reader :notifiers

      # @!attribute [w] threshold
      #   @return [Integer, nil] The default failure threshold to trip the circuit breaker.
      attr_writer :threshold

      # @!attribute [w] window_size
      #   @return [Integer, nil] The default size of the rolling window for failure tracking.
      attr_writer :window_size

      # @!attribute [w] tracked_errors
      #   @return [Array<Class>, nil] The default list of errors to track.
      attr_writer :tracked_errors

      # @!attribute [w] skipped_errors
      #   @return [Array<Class>, nil] The default list of errors to skip.
      attr_writer :skipped_errors

      def initialize
        # This allows users appending notifiers to the default list,
        # while still allowing them to override the default list.
        @notifiers = Default::NOTIFIERS
      end

      # @param value [Stoplight::DataStore::Base]
      # @return [Stoplight::DataStore::Base] The default data store instance.
      def data_store=(value)
        @data_store = DataStore::FailSafe.wrap(value)
      end

      # @param value [Array<Stoplight::Notifier::Base>]
      # @return [Array<Stoplight::Notifier::FailSafe>]
      def notifiers=(value)
        @notifiers = value.map { |notifier| Notifier::FailSafe.wrap(notifier) }
      end

      # Converts the user-defined configuration to a hash.
      #
      # @return [Hash] A hash representation of the configuration, excluding nil values.
      # @api private
      def to_h
        {
          cool_off_time: @cool_off_time,
          data_store: @data_store,
          error_notifier: @error_notifier,
          notifiers: (@notifiers == Default::NOTIFIERS) ? nil : @notifiers, # This is to avoid conflicts with legacy config
          threshold: @threshold,
          window_size: @window_size,
          tracked_errors: @tracked_errors,
          skipped_errors: @skipped_errors
        }.compact
      end

      # @return [Boolean] True if the configuration hash is not empty, false otherwise.
      # @api private
      def_delegator :to_h, :any?
    end
  end
end
