# frozen_string_literal: true

module Stoplight
  module Wiring
    class GlobalState
      attr_reader :default_system
      attr_reader :default_config

      def initialize(default_config:)
        @default_config = default_config
        @systems = Concurrent::Map.new
        @default_system = create_system(config: default_config.with(name: "default"))
      end

      def create_system(config:)
        @systems.compute(config.name.to_s) do |existing_system|
          if existing_system
            raise ArgumentError, "system `#{config.name}` is already in use"
          else
            Wiring::System.new(
              config: config,
              failover_system: Wiring::System.new(
                config: Wiring::FailSafeConfig.with(name: "__stoplight__:failover:#{config.name}"),
                failover_system: nil,
                registry: Infrastructure::Memory::Storage::Registry.new
              ),
              registry: create_registry(config)
            )
          end
        end
      end

      private

      def create_registry(config)
        case config.data_store
        when DataStore::Redis
          Infrastructure::Redis::Storage::Registry.new(
            redis: redis(config),
            key_space: Infrastructure::Redis::Storage::SystemKeySpace.build(system_name: config.name.to_s),
            clock: Infrastructure::SystemClock.new
          )
        else
          Infrastructure::Memory::Storage::Registry.new
        end
      end

      def redis(config)
        case config.data_store
        when DataStore::Redis
          config.data_store.redis
        else
          raise TypeError, "Expected Stoplight::DataStore::Redis, got #{config.data_store.class}"
        end
      end
    end
  end
end
