# frozen_string_literal: true

module Stoplight
  module Domain
    module Tracker
      class RecoveryProbe < Base
        # @!attribute [r] data_store
        #   @return [Stoplight::DataStore::Base] The data store associated with the light.
        protected attr_reader :data_store

        # @!attribute [r] traffic_recovery
        #   @return [Stoplight::Domain::TrafficRecovery::Base]
        protected attr_reader :traffic_recovery

        # @!attribute [r] traffic_control
        #   @return [Stoplight::Domain::TrafficControl::Base]
        protected attr_reader :notifiers

        # @!attribute [r] config
        #   @return [Stoplight::Domain::Config] The configuration for the light.
        protected attr_reader :config

        # @!attribute [r] metrics_store
        #   @return [Stoplight::Domain::Storage::Metrics]
        protected attr_reader :metrics_store

        # @param data_store [Stoplight::Domain::DataStore]
        # @param traffic_recovery [Stoplight::Domain::TrafficRecovery::Base]
        # @param notifiers [<Stoplight::Domain::StateTransitionNotifier>]
        # @param config [Stoplight::Domain::Config]
        # @param metrics_store [Stoplight::Domain::Storage::Metrics]
        def initialize(data_store:, traffic_recovery:, notifiers:, config:, metrics_store:)
          @data_store = data_store
          @traffic_recovery = traffic_recovery
          @notifiers = notifiers
          @config = config
          @metrics_store = metrics_store
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
        RECOVERY_TRANSITIONS = {
          TrafficRecovery::GREEN => [Color::YELLOW, Color::GREEN],
          TrafficRecovery::RED => [Color::YELLOW, Color::RED]
        }.freeze

        private def recover
          recovery_metrics = metrics_store.metrics_snapshot
          recovery_result = traffic_recovery.determine_color(config, recovery_metrics)

          return if recovery_result == TrafficRecovery::YELLOW

          from_color, to_color = RECOVERY_TRANSITIONS.fetch(recovery_result) do
            raise "recovery strategy returned unexpected color: #{recovery_result}"
          end

          data_store.transition_to_color(config, to_color)
          metrics_store.clear
          notifiers.each do |notifier|
            notifier.notify(config, from_color, to_color, nil)
          end
        end
      end
    end
  end
end
