# frozen_string_literal: true

module Stoplight
  module Domain
    module Tracker
      # Tracks request outcomes (success/failure) and manages state transitions
      # for normal traffic.
      #
      # Used by +GreenRunStrategy+ to track failures and potentially open the circuit.
      #
      # @api private
      class Request < Base
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
          data_store.record_failure(config, exception)
          metrics = data_store.get_metrics(config)

          transition_to_red(exception, metrics:)
        end

        # @return [void]
        def record_success
          data_store.record_success(config)
        end

        private def transition_to_red(exception, metrics:)
          if traffic_control.stop_traffic?(config, metrics)
            # Returns true only if not yet in red therefore preventing
            # duplicate notifications
            if data_store.transition_to_color(config, Color::RED)
              notifiers.each do |notifier|
                notifier.notify(config, Color::GREEN, Color::RED, exception)
              end
            end
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
end
