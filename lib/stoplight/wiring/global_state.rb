# frozen_string_literal: true

module Stoplight
  module Wiring
    class GlobalState
      attr_reader :default_system
      attr_reader :default_config

      DEFAULT_SYSTEM_NAME = "__stoplight__default_system"
      private_constant :DEFAULT_SYSTEM_NAME

      def initialize(default_config:)
        @default_config = default_config.with(name: DEFAULT_SYSTEM_NAME)
        @systems = Concurrent::Map.new
        @default_system = create_system(config: default_config.with(name: "default"))
      end

      def create_system(config:)
        @systems.compute(config.name.to_s) do |existing_system|
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

      private

      def create_registry(config, failover_system)
        case config.data_store
        when DataStore::Redis
          Infrastructure::FailSafe::Storage::Registry.new(
            primary_registry: Infrastructure::Redis::Storage::Registry.new(
              redis: config.data_store.redis,
              key_space: Infrastructure::Redis::Storage::SystemKeySpace.build(system_name: config.name.to_s),
              clock: Infrastructure::SystemClock.new
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
