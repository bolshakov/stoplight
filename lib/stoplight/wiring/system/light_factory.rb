# frozen_string_literal: true

module Stoplight
  module Wiring
    class System
      class LightFactory < Wiring::LightFactory
        def initialize(system_name:, config:, failover_system:)
          @system_name = system_name
          @failover_system = failover_system

          super(config:)
        end

        def key_space = @key_space ||= Infrastructure::Redis::Storage::KeySpace.build(
          system_name: system_name,
          light_name: config.name
        )

        def storage_set
          @storage_set ||= StorageSetBuilder.new(backend: build_backend, windowed: !config.window_size.nil?).build
        end

        attr_reader :system_name

        def state_store = storage_set.state_store
        def recovery_lock_store = storage_set.recovery_lock_store
        def recovery_metrics_store = storage_set.recovery_metrics_store
        def metrics_store = storage_set.metrics_store
        def storage_scripting = Infrastructure::Redis::Storage::Scripting.new(redis:)

        def failover_system = T.must(@failover_system)

        def build_backend
          case data_store_config
          in DataStore::Memory
            Memory::Backend.new(clock:, config:)
          in DataStore::Redis
            Redis::Backend.new(
              redis:, scripting: storage_scripting, key_space:, clock:, config:, error_notifier:,
              failover_light: create_circuit_breaker("redis")
            )
          end
        end

        def create_circuit_breaker(name)
          failover_system.light(name)
        end
      end
    end
  end
end
