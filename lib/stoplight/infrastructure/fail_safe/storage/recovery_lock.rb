# frozen_string_literal: true

require "securerandom"

module Stoplight
  module Infrastructure
    module FailSafe
      module Storage
        # A wrapper around a store that provides fail-safe mechanisms using a
        # circuit breaker. It ensures that operations on the store can gracefully
        # handle failures by falling back to default values when necessary.
        #
        # @api private
        class RecoveryLock
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

          def acquire_lock
            fallback = ->(error) {
              error_notifier.call(error) if error
              wrap_token(:failover, failover_store.acquire_lock)
            }
            circuit_breaker.run(fallback) do
              wrap_token(:primary, primary_store.acquire_lock)
            end
          end

          # Routes release to correct store based on token type.
          # Redis tokens release via primary (with error notification on failure).
          # Memory tokens release via failover directly.
          #
          def release_lock(recovery_lock_token)
            case recovery_lock_token.origin
            in :primary
              fallback = ->(error) {
                error_notifier.call(error) if error
              }

              circuit_breaker.run(fallback) do
                primary_store.release_lock(recovery_lock_token.underlying_token)
              end
            in :failover
              failover_store.release_lock(recovery_lock_token.underlying_token)
            end
          end

          private

          # The circuit breaker used to handle store failures.
          attr_reader :circuit_breaker

          def wrap_token(origin, token)
            RecoveryLockToken.new(origin:, underlying_token: token) if token
          end
        end
      end
    end
  end
end
