# frozen_string_literal: true

module Stoplight
  module Wiring
    class GlobalState
      attr_reader :default_system
      attr_reader :default_config

      def initialize(default_config:)
        @default_config = default_config
        @systems = Concurrent::Map.new
        @default_system = register_system_with_config(@default_config)
      end

      def register_system(
        name,
        cool_off_time: T.undefined,
        threshold: T.undefined,
        recovery_threshold: T.undefined,
        window_size: T.undefined,
        tracked_errors: T.undefined,
        skipped_errors: T.undefined,
        data_store: T.undefined,
        error_notifier: T.undefined,
        notifiers: T.undefined,
        traffic_control: T.undefined,
        traffic_recovery: T.undefined
      )
        register_system_with_config(
          Wiring::SystemConfigurationDsl.new(
            name,
            cool_off_time:,
            threshold:,
            recovery_threshold:,
            window_size:,
            tracked_errors:,
            skipped_errors:,
            traffic_control:,
            traffic_recovery:,
            data_store:,
            error_notifier:,
            notifiers:
          ).configure!(@default_config)
        )
      end

      private

      def register_system_with_config(config)
        @systems.compute(config.name) do |existing_system|
          if existing_system
            raise ArgumentError, "system `#{config.name}` is already in use"
          else
            failover_system = Wiring::System.new(
              config: Wiring::FailSafeConfig.with(
                name: "__stoplight__:failover:#{config.name}",
                data_store: DataStore::Memory.new
              ),
              failover_system: nil,
              registry: Infrastructure::Memory::Storage::Registry.new
            )
            Wiring::System.new(
              config: config,
              failover_system: failover_system,
              registry: create_registry(config, failover_system)
            )
          end
        end
      end

      def create_registry(config, failover_system)
        case config.data_store
        when DataStore::Redis
          Infrastructure::FailSafe::Storage::Registry.new(
            primary_registry: Infrastructure::Redis::Storage::Registry.new(
              redis: config.data_store.redis,
              key_space: Infrastructure::Redis::Storage::SystemKeySpace.build(system_name: config.name.to_s),
              clock: Infrastructure::SystemClock.new,
              config_serializer: Infrastructure::ConfigSerializer
            ),
            error_notifier: config.error_notifier,
            failover_registry: Infrastructure::Memory::Storage::Registry.new,
            circuit_breaker: failover_system.register("registry")
          )
        when DataStore::Memory
          Infrastructure::Memory::Storage::Registry.new
        else
          raise TypeError, "unsupported data store type"
        end
      end
    end
  end
end
