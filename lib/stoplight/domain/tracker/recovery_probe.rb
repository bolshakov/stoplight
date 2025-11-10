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

        # @param data_store [Stoplight::Domain::DataStore]
        # @param traffic_recovery [Stoplight::Domain::TrafficRecovery::Base]
        # @param notifiers [<Stoplight::Domain::StateTransitionNotifier>]
        # @param config [Stoplight::Domain::Config]
        def initialize(data_store:, traffic_recovery:, notifiers:, config:)
          @data_store = data_store
          @traffic_recovery = traffic_recovery
          @notifiers = notifiers
          @config = config
        end

        # @param exception [Exception]
        def record_failure(exception)
          data_store.record_recovery_probe_failure(config, exception)

          recover
        end

        def record_success
          data_store.record_recovery_probe_success(config)

          recover
        end
        RECOVERY_TRANSITIONS = {
          TrafficRecovery::GREEN => [Color::YELLOW, Color::GREEN],
          TrafficRecovery::YELLOW => [Color::RED, Color::YELLOW],
          TrafficRecovery::RED => [Color::YELLOW, Color::RED]
        }.freeze

        private def recover
          recovery_metrics = data_store.get_recovery_metrics(config)
          state_snapshot = data_store.get_state_snapshot(config) # TODO: is this really necessary?

          recovery_result = traffic_recovery.determine_color(config, recovery_metrics, state_snapshot)

          return if recovery_result == TrafficRecovery::PASS

          from_color, to_color = RECOVERY_TRANSITIONS.fetch(recovery_result) do
            raise "recovery strategy returned unexpected color: #{recovery_result}"
          end

          transition_and_notify(from_color, to_color, nil)
        end

        # @param other [any]
        # @return [bool]
        def ==(other)
          super && traffic_recovery == other.traffic_recovery
        end
      end
    end
  end
end
