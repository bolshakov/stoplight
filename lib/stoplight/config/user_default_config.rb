# frozen_string_literal: true

require "forwardable"
require_relative "traffic_control_builder"

module Stoplight
  module Config
    # Represents user-defined default configuration for Stoplight.
    #
    # This class allows users to define default settings for various Stoplight
    # parameters, such as cool-off time, data store, error notifier, and more.
    # TODO: add evaluation/recovery strategy support
    class UserDefaultConfig
      extend Forwardable
      include TrafficControlBuilder

      # @!attribute [w] cool_off_time
      #   @return [Integer, nil] The default cool-off time in seconds.
      attr_writer :cool_off_time

      # @!attribute [w] error_notifier
      #   @return [Proc, nil] The default error notifier (callable object).
      attr_writer :error_notifier

      # @!attribute [rw] notifiers
      #   @return [Array<Stoplight::Notifier::Base>] The default list of notifiers.
      attr_accessor :notifiers

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

      # @!attribute [w] data_store
      #   @return [Stoplight::DataStore::Base] The default data store instance.
      attr_writer :data_store

      # @!attribute [w] traffic_control
      #   @return [Stoplight::TrafficControl::Base, nil] The default traffic control strategy.
      attr_writer :traffic_control

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
        tc = build_traffic_control(@traffic_control)
        {
          cool_off_time: @cool_off_time,
          data_store: @data_store,
          error_notifier: @error_notifier,
          notifiers: @notifiers,
          threshold: @threshold,
          window_size: @window_size,
          tracked_errors: @tracked_errors,
          skipped_errors: @skipped_errors,
          traffic_control: tc
        }.compact
      end

      # @return [Boolean] True if the configuration hash is not empty, false otherwise.
      # @api private
      def_delegator :to_h, :any?
    end
  end
end
