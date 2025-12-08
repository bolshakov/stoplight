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
        class State < Domain::Storage::State
          # @!attribute primary_store
          #  @return [Stoplight::Domain::Storage::RecoveryLock] The underlying primary store being used
          attr_reader :primary_store

          # @!attribute error_notifier
          #   @return [Proc]
          attr_reader :error_notifier

          # @!attribute failover_store
          #   @return [Stoplight::Domain::Storage::RecoveryLock] The fallback store used when the primary fails.
          attr_reader :failover_store

          # @!attribute circuit_breaker
          #   @return [Stoplight::Light] The circuit breaker used to handle store failures.
          private attr_reader :circuit_breaker

          # @param primary_store [Stoplight::Domain::Storage::RecoveryLock]
          # @param error_notifier [Proc]
          # @param failover_store [Stoplight::Domain::Storage::RecoveryLock]
          # @param circuit_breaker [Stoplight::Domain::Light]
          def initialize(primary_store:, error_notifier:, failover_store:, circuit_breaker:)
            @primary_store = primary_store
            @error_notifier = error_notifier
            @failover_store = failover_store
            @circuit_breaker = circuit_breaker
          end

          # @param state [String]
          # @return [String]
          def set_state(state)
            circuit_breaker.run(fallback { failover_store.set_state(state) }) do
              primary_store.set_state(state)
            end
          end

          def state_snapshot
            circuit_breaker.run(fallback { failover_store.state_snapshot }) do
              primary_store.state_snapshot
            end
          end

          # @param color [String]
          # @return [Boolean]
          def transition_to_color(color)
            circuit_breaker.run(fallback { failover_store.transition_to_color(color) }) do
              primary_store.transition_to_color(color)
            end
          end

          def clear
            circuit_breaker.run(fallback { failover_store.clear }) do
              primary_store.clear
            end
          end

          private def fallback(&fallback)
            proc do |error|
              error_notifier.call(error) if error
              fallback.call
            end
          end
        end
      end
    end
  end
end
