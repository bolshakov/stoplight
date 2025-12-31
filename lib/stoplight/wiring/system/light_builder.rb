# frozen_string_literal: true

module Stoplight
  module Wiring
    class System
      class LightBuilder < Wiring::LightBuilder
        # @dynamic system
        private attr_reader :system

        def initialize(system, settings)
          @system = system

          super(settings)
        end

        def key_space = @key_space ||= Infrastructure::Storage::Redis::KeySpace.build(
          system_name: system.name,
          light_name: config.name
        )

        def cool_off_time = config.cool_off_time

        private def state_store
          @state_store ||= case data_store_config
          in Stoplight::DataStore::Memory
            Infrastructure::Storage::Memory::State.new(clock:, cool_off_time:)
          in Stoplight::DataStore::Redis
            Infrastructure::Storage::FailSafe::State.new(
              primary_store: Infrastructure::Storage::Redis::State.new(
                redis: data_store_config.redis,
                scripting:,
                key_space:,
                cool_off_time:,
                clock:
              ),
              error_notifier:,
              failover_store: Infrastructure::Storage::Memory::State.new(clock:, cool_off_time:),
              circuit_breaker: failover_system.light("redis")
            )
          end
        end

        def recovery_lock_store
          @recovery_lock_store ||= case data_store_config
          in Stoplight::DataStore::Memory
            Infrastructure::Storage::Memory::RecoveryLock.new
          in Stoplight::DataStore::Redis
            Infrastructure::Storage::FailSafe::RecoveryLock.new(
              primary_store: Infrastructure::Storage::Redis::RecoveryLock.new(
                config:,
                redis: data_store_config.redis,
                scripting:,
                key_space:
              ),
              error_notifier:,
              failover_store: Infrastructure::Storage::Memory::RecoveryLock.new,
              circuit_breaker: failover_system.light("redis")
            )
          end
        end

        private def redis = data_store_config
        private def storage_scripting = Infrastructure::Storage::Redis::Scripting.new(redis:)
        private def failover_system = @failover_system ||= Stoplight.__stoplight__system("failover-#{system.name}")
      end
    end
  end
end
