# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module FailSafe
      module Storage
        # A wrapper around a store that provides fail-safe mechanisms using a
        # circuit breaker. It ensures that operations on the store can gracefully
        # handle failures by falling back to default values when necessary.
        #
        # @api private
        class Metrics
          # The underlying primary store being used
          attr_reader :primary_store
          attr_reader :error_notifier
          # The fallback store used when the primary fails.
          attr_reader :failover_store

          def initialize(primary_store:, error_notifier:, failover_store:, circuit_breaker:)
            @primary_store = primary_store
            @error_notifier = error_notifier
            @failover_store = failover_store
            @circuit_breaker = circuit_breaker
          end

          def metrics_snapshot
            circuit_breaker.run(fallback { failover_store.metrics_snapshot }) do
              primary_store.metrics_snapshot
            end
          end

          def record_success
            circuit_breaker.run(fallback { failover_store.record_success }) do
              primary_store.record_success
            end
          end

          def record_failure(exception)
            circuit_breaker.run(fallback { failover_store.record_failure(exception) }) do
              primary_store.record_failure(exception)
            end
          end

          def clear
            circuit_breaker.run(fallback { failover_store.clear }) do
              primary_store.clear
            end
          end

          private

          # The circuit breaker used to handle store failures.
          attr_reader :circuit_breaker

          def fallback(&fallback)
            ->(error) {
              error_notifier.call(error) if error
              fallback.call
            }
          end
        end
      end
    end
  end
end
