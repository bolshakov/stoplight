# frozen_string_literal: true

require "securerandom"

module Stoplight
  module Infrastructure
    module Storage
      module FailSafe
        # A wrapper around a store that provides fail-safe mechanisms using a
        # circuit breaker. It ensures that operations on the store can gracefully
        # handle failures by falling back to default values when necessary.
        #
        # @api private
        class RecoveryLock < Domain::Storage::RecoveryLock
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

          def acquire_lock
            fallback = proc do |error|
              error_notifier.call(error) if error
              failover_store.acquire_lock
            end
            circuit_breaker.run(fallback) do
              primary_store.acquire_lock
            end
          end

          # Routes release to correct store based on token type.
          # Redis tokens release via primary (with error notification on failure).
          # Memory tokens release via failover directly.
          #
          # @param recovery_lock_token [Stoplight::Domain::RecoveryLockToken]
          def release_lock(recovery_lock_token)
            case recovery_lock_token
            in Redis::RecoveryLockToken
              fallback = -> { |error|
                error_notifier.call(error) if error
              }

              circuit_breaker.run(fallback) do
                primary_store.release_lock(recovery_lock_token)
              end
            in Memory::RecoveryLockToken
              failover_store.release_lock(recovery_lock_token)
            end
          end
        end
      end
    end
  end
end
