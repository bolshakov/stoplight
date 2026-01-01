# frozen_string_literal: true

require "securerandom"
require "forwardable"

module Stoplight
  module Infrastructure
    module Redis
      class DataStore
        # Distributed recovery lock using Redis SET NX (set-if-not-exists).
        #
        # Lock Acquisition:
        # - Uses unique UUID token to prevent accidental release of others' locks
        # - Atomic SET with NX flag ensures only one process acquires recovery_lock
        # - TTL (px: lock_timeout) auto-releases recovery_lock if process crashes
        #
        # Lock Release:
        # - Lua script ensures only token holder can release (token comparison)
        # - Best-effort release; TTL cleanup handles failures
        #
        # Failure Modes:
        # - Lock contention: Returns false, caller should skip probe
        # - Redis unavailable: raises an error and let caller decide
        # - Crashed holder: raises an error and let caller decide. Lock auto-expires after lock_timeout
        # - Release failure: Lock auto-expires after lock_timeout
        #
        class RecoveryLockStore
          # @!attribute redis
          #   @return [RedisClient]
          # @dynamic redis
          protected attr_reader :redis

          # @!attribute lock_timeout
          #   @return [Integer]
          # @dynamic lock_timeout
          protected attr_reader :lock_timeout

          # @!attribute scripting
          #   @return [Stoplight::Infrastructure::Redis::DataStore::Scripting]
          # @dynamic scripting
          protected attr_reader :scripting

          # @param redis [RedisClient | ConnectionPool]
          # @param lock_timeout [Integer] recovery_lock timeout in milliseconds
          # @param scripting [Stoplight::Infrastructure::Redis::DataStore::Scripting]
          def initialize(redis:, lock_timeout:, scripting:)
            @redis = redis
            @lock_timeout = lock_timeout
            @scripting = scripting
          end

          # @param light_name [String]
          # @return [Stoplight::Infrastructure::Redis::DataStore::RecoveryLockToken, nil]
          def acquire_lock(light_name)
            recovery_lock = RecoveryLockToken.new(light_name:)

            acquired = !!redis.then do |client|
              client.set(recovery_lock.lock_key, recovery_lock.token, nx: true, px: lock_timeout)
            end

            recovery_lock if acquired
          end

          # @param recovery_lock [Stoplight::Infrastructure::Redis::DataStore::RecoveryLockToken]
          # @return [void]
          def release_lock(recovery_lock)
            scripting.call(
              :release_lock,
              keys: [recovery_lock.lock_key], args: [recovery_lock.token]
            )
          end
        end
      end
    end
  end
end
