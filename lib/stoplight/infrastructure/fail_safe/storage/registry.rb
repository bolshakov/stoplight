# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module FailSafe
      module Storage
        class Registry
          def initialize(primary_registry:, error_notifier:, failover_registry:, circuit_breaker:)
            @primary_registry = primary_registry
            @error_notifier = error_notifier
            @failover_registry = failover_registry
            @circuit_breaker = circuit_breaker
          end

          def ids
            fallback = ->(error) {
              @error_notifier.call(error) if error
              @failover_registry.ids
            }
            @circuit_breaker.run(fallback) do
              @primary_registry.ids
            end
          end

          def all_configs
            fallback = ->(error) {
              @error_notifier.call(error) if error
              @failover_registry.all_configs
            }
            @circuit_breaker.run(fallback) do
              @primary_registry.all_configs
            end
          end

          def register(config)
            fallback = ->(error) {
              @error_notifier.call(error) if error
              @failover_registry.register(config)
            }
            @circuit_breaker.run(fallback) do
              @primary_registry.register(config)
            end
          end

          def unregister(id)
            fallback = ->(error) {
              @error_notifier.call(error) if error
              @failover_registry.unregister(id)
            }
            @circuit_breaker.run(fallback) do
              @primary_registry.unregister(id)
            end
          end

          def config_for(id)
            fallback = ->(error) {
              @error_notifier.call(error) if error
              @failover_registry.config_for(id)
            }
            @circuit_breaker.run(fallback) do
              @primary_registry.config_for(id)
            end
          end
        end
      end
    end
  end
end
