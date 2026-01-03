# frozen_string_literal: true

module Stoplight
  module Wiring
    class System
      class LightBuilder < Wiring::LightBuilder
        private attr_reader :system

        def initialize(system, settings)
          @system = system

          super(settings)
        end

        def key_space = @key_space ||= Infrastructure::Redis::Storage::KeySpace.build(
          system_name: system.name,
          light_name: config.name
        )

        private def state_store = storage_set.state_store
        private def recovery_lock_store = storage_set.recovery_lock_store
        private def recovery_metrics_store = storage_set.recovery_metrics_store
        private def metrics_store = storage_set.metrics_store

        private def redis
          case data_store_config
          when DataStore::Redis
            data_store_config.redis
          else
            raise TypeError, "should be redis"
          end
        end
        private def storage_scripting = Infrastructure::Redis::Storage::Scripting.new(redis:)
        private def failover_system = @failover_system ||= Stoplight.__stoplight__system("failover-#{system.name}")

        def storage_set
          @storage_set ||= StorageSetBuilder.new(backend: build_backend, windowed: !config.window_size.nil?).build
        end

        private def build_backend
          case data_store_config
          in DataStore::Memory
            Memory::Backend.new(clock:, config:)
          in DataStore::Redis
            Redis::Backend.new(
              redis:, scripting: storage_scripting, key_space:, clock:, config:, error_notifier:,
              failover_light: failover_system.light("redis")
            )
          end
        end
      end
    end
  end
end
