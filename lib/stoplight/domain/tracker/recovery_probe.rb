# frozen_string_literal: true

module Stoplight
  module Domain
    module Tracker
      class RecoveryProbe < Base
        # @!attribute [r] traffic_recovery
        #   @return [Stoplight::Domain::TrafficRecovery::Base]
        # @dynamic traffic_recovery
        protected attr_reader :traffic_recovery

        # @!attribute [r] traffic_control
        #   @return [Stoplight::Domain::TrafficControl::Base]
        # @dynamic notifiers
        protected attr_reader :notifiers

        # @!attribute [r] config
        #   @return [Stoplight::Domain::Config] The configuration for the light.
        # @dynamic config
        protected attr_reader :config

        # @!attribute [r] metrics_store
        #   @return [Stoplight::Domain::Storage::Metrics]
        # @dynamic metrics_store
        protected attr_reader :metrics_store

        # @!attribute [r] state_store
        #   @return [Stoplight::Domain::Storage::State]
        # @dynamic state_store
        protected attr_reader :state_store

        # @param traffic_recovery [Stoplight::Domain::TrafficRecovery::Base]
        # @param notifiers [<Stoplight::Domain::StateTransitionNotifier>]
        # @param config [Stoplight::Domain::Config]
        # @param metrics_store [Stoplight::Domain::Storage::Metrics]
        # @param state_store [Stoplight::Domain::Storage::State]
        def initialize(traffic_recovery:, notifiers:, config:, metrics_store:, state_store:)
          @traffic_recovery = traffic_recovery
          @notifiers = notifiers
          @config = config
          @metrics_store = metrics_store
          @state_store = state_store
        end

        # @param exception [Exception]
        def record_failure(exception)
          metrics_store.record_failure(exception)

          recover
        end

        def record_success
          metrics_store.record_success

          recover
        end

        private def recover
          recovery_metrics = metrics_store.metrics_snapshot
          recovery_result = traffic_recovery.determine_color(config, recovery_metrics)

          return if recovery_result == TrafficRecovery::YELLOW

          from_color, to_color = case recovery_result
          when TrafficRecovery::GREEN then [Color::YELLOW, Color::GREEN]
          when TrafficRecovery::RED then [Color::YELLOW, Color::RED]
          else
            raise "recovery strategy returned unexpected color: #{recovery_result}"
          end

          state_store.transition_to_color(to_color)
          metrics_store.clear
          notifiers.each do |notifier|
            notifier.notify(config, from_color, to_color, nil)
          end
        end
      end
    end
  end
end
