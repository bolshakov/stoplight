# frozen_string_literal: true

require "securerandom"
require "forwardable"

module Stoplight
  module Infrastructure
    module DataStore
      class Redis
        # Distributed recovery recovery_lock using Redis SET NX (set-if-not-exists).
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
          private attr_reader :redis

          # @!attribute lock_timeout
          #   @return [Integer]
          private attr_reader :lock_timeout

          # @param redis [RedisClient | ConnectionPool]
          # @param lock_timeout [Integer] recovery_lock timeout in milliseconds
          def initialize(redis:, lock_timeout:)
            @redis = redis
            @lock_timeout = lock_timeout
          end

          # @param light_name [String]
          # @return [Stoplight::Infrastructure::DataStore::Redis::RecoveryLockToken, nil]
          def acquire_lock(light_name)
            recovery_lock = RecoveryLockToken.new(light_name:)

            acquired = !!redis.then do |client|
              client.set(recovery_lock.lock_key, recovery_lock.token, nx: true, px: lock_timeout)
            end

            recovery_lock if acquired
          end

          # @param recovery_lock [Stoplight::Infrastructure::DataStore::Redis::RecoveryLockToken]
          # @return [void]
          def release_lock(recovery_lock)
            # TODO: Use Script Manager
            redis.then do |client|
              client.eval(<<~LUA, keys: [recovery_lock.lock_key], argv: [recovery_lock.token])
                local token = ARGV[1] 
                local lock_key = KEYS[1]
  
                if redis.call("get", lock_key) == token then
                  return redis.call("del", lock_key)
                end
              LUA
            end
          end
        end
      end
    end
  end
end
