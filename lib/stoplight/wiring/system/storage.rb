# frozen_string_literal: true

module Stoplight
  module Wiring
    class System
      class Storage
        def initialize(system_name:, failover_system:)
          @system_name = system_name
          @failover_system = failover_system
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
          LightFactory.new(system_name: @system_name, config:, failover_system: @failover_system).state_store
        end

        private def metrics_store(config)
          LightFactory.new(system_name: @system_name, config:, failover_system: @failover_system).metrics_store
        end
      end
    end
  end
end
