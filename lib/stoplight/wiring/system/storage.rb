# frozen_string_literal: true

module Stoplight
  module Wiring
    class System
      # Only for admin panel use.
      class Storage
        def initialize(system_name:, failover_system:, telemetry:)
          @system_name = system_name
          @failover_system = failover_system
          @factories = {}
          @telemetry = telemetry
        end

        def state_snapshot(config)
          state_store(config).state_snapshot
        end

        def metrics_snapshot(config)
          metrics_store(config).metrics_snapshot
        end

        def delete(config)
          state_store(config).clear
          metrics_store(config).clear
        end

        private def state_store(config)
          light_factory(config).state_store
        end

        private def metrics_store(config)
          light_factory(config).metrics_store
        end

        private def light_factory(config)
          @factories[config] ||= LightFactory.new(
            system_name: @system_name,
            config:,
            failover_system: @failover_system,
            telemetry: @telemetry
          )
        end
      end
    end
  end
end
