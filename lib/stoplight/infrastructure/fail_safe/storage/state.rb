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
        class State
          attr_reader :primary_store
          attr_reader :error_notifier
          attr_reader :failover_store
          attr_reader :circuit_breaker

          def initialize(primary_store:, error_notifier:, failover_store:, circuit_breaker:)
            @primary_store = primary_store
            @error_notifier = error_notifier
            @failover_store = failover_store
            @circuit_breaker = circuit_breaker
          end

          def set_state(state)
            circuit_breaker.run(fallback { failover_store.set_state(state) }) do
              primary_store.set_state(state)
            end
          end

          # @return [Stoplight::Domain::StateSnapshot]
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
