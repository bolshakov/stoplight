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

          def names
            fallback = ->(error) {
              @error_notifier.call(error) if error
              @failover_registry.names
            }
            @circuit_breaker.run(fallback) do
              @primary_registry.names
            end
          end

          def register(name, config:)
            fallback = ->(error) {
              @error_notifier.call(error) if error
              @failover_registry.register(name, config:)
            }
            @circuit_breaker.run(fallback) do
              @primary_registry.register(name, config:)
            end
          end

          def unregister(name)
            fallback = ->(error) {
              @error_notifier.call(error) if error
              @failover_registry.unregister(name)
            }
            @circuit_breaker.run(fallback) do
              @primary_registry.unregister(name)
            end
          end
        end
      end
    end
  end
end
