# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Storage
      module FailSafe
        # A wrapper around a store that provides fail-safe mechanisms using a
        # circuit breaker. It ensures that operations on the store can gracefully
        # handle failures by falling back to default values when necessary.
        #
        # @api private
        class Metrics < Domain::Storage::Metrics
          # @!attribute primary_store
          #  @return [Stoplight::Domain::Storage::RecoveryLock] The underlying primary store being used
          # @dynamic primary_store
          attr_reader :primary_store

          # @!attribute error_notifier
          #   @return [Proc]
          # @dynamic error_notifier
          attr_reader :error_notifier

          # @!attribute failover_store
          #   @return [Stoplight::Domain::Storage::RecoveryLock] The fallback store used when the primary fails.
          # @dynamic failover_store
          attr_reader :failover_store

          # @!attribute circuit_breaker
          #   @return [Stoplight::Light] The circuit breaker used to handle store failures.
          # @dynamic circuit_breaker
          private attr_reader :circuit_breaker

          # @param primary_store [Stoplight::Domain::Storage::Metrics]
          # @param error_notifier [Proc]
          # @param failover_store [Stoplight::Domain::Storage::Metrics]
          # @param circuit_breaker [Stoplight::Domain::Light]
          def initialize(primary_store:, error_notifier:, failover_store:, circuit_breaker:)
            @primary_store = primary_store
            @error_notifier = error_notifier
            @failover_store = failover_store
            @circuit_breaker = circuit_breaker
          end

          # @return [Stoplight::Domain::StateSnapshot]
          def metrics_snapshot
            circuit_breaker.run(fallback { failover_store.metrics_snapshot }) do
              primary_store.metrics_snapshot
            end
          end

          # @return [void]
          def record_success
            circuit_breaker.run(fallback { failover_store.record_success }) do
              primary_store.record_success
            end
          end

          # @param exception [StandardError]
          # @return [void]
          def record_failure(exception)
            circuit_breaker.run(fallback { failover_store.record_failure(exception) }) do
              primary_store.record_failure(exception)
            end
          end

          # @return [void]
          def clear
            circuit_breaker.run(fallback { failover_store.clear }) do
              primary_store.clear
            end
          end

          private def fallback(&fallback)
            -> { |error|
              error_notifier.call(error) if error
              fallback.call
            }
          end
        end
      end
    end
  end
end
