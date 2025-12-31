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
        # @!attribute [r] traffic_control
        #   @return [Stoplight::Domain::TrafficControl::Base]
        # @dynamic traffic_control
        protected attr_reader :traffic_control

        # @!attribute [r] traffic_control
        #   @return [Stoplight::Domain::TrafficControl::Base]
        # @dynamic notifiers
        protected attr_reader :notifiers

        # @!attribute [r] config
        #   @return [Stoplight::Domain::Config] The configuration for the light.
        # @dynamic config
        protected attr_reader :config

        # @!attribute metrics_store
        #   @return [Stoplight::Storage::MetricsSnapshot]
        # @dynamic metrics_store
        protected attr_reader :metrics_store

        # @!attribute [r] state_store
        #   @return [Stoplight::Domain::Storage::State]
        # @dynamic state_store
        protected attr_reader :state_store

        # @param traffic_control [Stoplight::Domain::TrafficControl::Base]
        # @param notifiers [<Stoplight::Domain::StateTransitionNotifier>]
        # @param config [Stoplight::Domain::Config]
        # @param metrics_store [Stoplight::Storage::MetricsSnapshot]
        # @param state_store [Stoplight::Domain::Storage::State]
        def initialize(traffic_control:, notifiers:, config:, metrics_store:, state_store:)
          @traffic_control = traffic_control
          @notifiers = notifiers
          @config = config
          @metrics_store = metrics_store
          @state_store = state_store
        end

        # @param exception [Exception]
        # @return [void]
        def record_failure(exception)
          metrics_store.record_failure(exception)
          metrics = metrics_store.metrics_snapshot

          transition_to_red(exception, metrics:)
        end

        # @return [void]
        def record_success = metrics_store.record_success

        private def transition_to_red(exception, metrics:)
          if traffic_control.stop_traffic?(config, metrics)
            # Returns true only if not yet in red therefore preventing
            # duplicate notifications
            if state_store.transition_to_color(Color::RED)
              notifiers.each do |notifier|
                notifier.notify(config, Color::GREEN, Color::RED, exception)
              end
            end
          end
        end
      end
    end
  end
end
