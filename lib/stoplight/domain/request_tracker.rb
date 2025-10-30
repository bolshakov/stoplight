# frozen_string_literal: true

module Stoplight
  module Domain
    # Tracks request outcomes (success/failure) and manages state transitions
    # for normal traffic.
    #
    # Used by +GreenRunStrategy+ to track failures and potentially open the circuit.
    #
    # @api private
    class RequestTracker < BaseTracker
      # @!attribute [r] data_store
      #   @return [Stoplight::DataStore::Base] The data store associated with the light.
      protected attr_reader :data_store

      # @!attribute [r] traffic_control
      #   @return [Stoplight::Domain::TrafficControl::Base]
      protected attr_reader :traffic_control

      # @!attribute [r] traffic_control
      #   @return [Stoplight::Domain::TrafficControl::Base]
      protected attr_reader :notifiers

      # @!attribute [r] config
      #   @return [Stoplight::Domain::Config] The configuration for the light.
      protected attr_reader :config

      # @param data_store [Stoplight::Domain::DataStore]
      # @param traffic_control [Stoplight::Domain::TrafficControl::Base]
      # @param notifiers [<Stoplight::Domain::StateTransitionNotifier>]
      # @param config [Stoplight::Domain::Config]
      def initialize(data_store:, traffic_control:, notifiers:, config:)
        @data_store = data_store
        @traffic_control = traffic_control
        @notifiers = notifiers
        @config = config
      end

      # @param exception [Exception]
      # @return [void]
      def record_failure(exception)
        failure = Failure.from_error(exception)
        metadata = data_store.record_failure(config, failure)

        transition_to_red_if_needed(exception, metadata:)
      end

      # @return [void]
      def record_success
        data_store.record_success(config)
      end

      private def transition_to_red_if_needed(exception, metadata:)
        if traffic_control.stop_traffic?(config, metadata)
          transition_and_notify(Color::GREEN, Color::RED, exception)
        end
      end

      # @param other [any]
      # @return [bool]
      def ==(other)
        super && traffic_control == other.traffic_control
      end
    end
  end
end
