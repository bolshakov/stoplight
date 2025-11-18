# frozen_string_literal: true

require "concurrent/map"

module Stoplight
  module Wiring
    class DataStoreFactory
      # @!attribute memory_registry
      #   @return [Concurrent::Map<Stoplight::Infrastructure::DataStore::Memory>]
      attr_reader :memory_registry

      def initialize
        @memory_registry = Concurrent::Map.new
      end

      # @param config [Stoplight::DataStore::Base]
      # @param container [Stoplight::Infrastructure::DependencyInjection::Container]
      # @return [Stoplight::Domain::DataStore]
      def create(config, container)
        case config
        in Stoplight::DataStore::Memory
          memory_registry.compute_if_absent(config.object_id) do
            config.create(container)
          end
        in Stoplight::DataStore::Redis
          Infrastructure::DataStore::FailSafe.new(
            data_store: config.create(container),
            error_notifier: container.resolve(:error_notifier),
            failover_data_store: container.resolve(:failover_data_store),
            circuit_breaker: Stoplight.system_light("data_store:fail_safe:redis")
          )
        end
      end
    end
  end
end
