# frozen_string_literal: true

require "securerandom"
require "forwardable"

module Stoplight
  module Infrastructure
    module DataStore
      class Redis
        # Distributed recovery lock using Redis SET NX (set-if-not-exists).
        #
        # Lock Acquisition:
        # - Uses unique UUID token to prevent accidental release of others' locks
        # - Atomic SET with NX flag ensures only one process acquires lock
        # - TTL (px: lock_timeout) auto-releases lock if process crashes
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
        class RecoveryLock < Domain::RecoveryLock
          extend Forwardable

          def_delegator "Stoplight::Infrastructure::DataStore::Redis", :key

          # @!attribute redis
          #   @return [RedisClient]
          private attr_reader :redis

          # @!attribute fail_safe_data_store
          #   @return [Stoplight::Infrastructure::DataStore::FailSafe]
          private attr_reader :data_store

          # @!attribute lock_timeout
          #   @return [Integer]
          private attr_reader :lock_timeout

          # @param redis [RedisClient | ConnectionPool]
          # @param data_store [Stoplight::Infrastructure::DataStore::Redis]
          # @param lock_timeout [Integer] lock timeout in milliseconds
          def initialize(redis:, data_store:, lock_timeout:)
            @redis = redis
            @data_store = data_store
            @lock_timeout = lock_timeout
          end

          # @param light_name [String]
          # @yieldparam [Stoplight::Domain::DataStore]
          def with_lock(light_name)
            token = SecureRandom.uuid
            lock_key = key(:recovery_lock, light_name)

            if acquire_lock(lock_key, token)
              begin
                yield data_store
              ensure
                release_lock(lock_key, token)
              end
              true
            else
              false
            end
          end

          # @return [Boolean] true if lock acquired, false overwise
          private def acquire_lock(lock_key, token)
            !!redis.then do |client|
              client.set(lock_key, token, nx: true, px: lock_timeout)
            end
          end

          # @param token [String] only delete if token matches (prevent releasing others' locks)
          # @return [Boolean] true if released
          private def release_lock(lock_key, token)
            # TODO: Use Script Manager
            released = redis.then do |client|
              client.eval(<<~LUA, keys: [lock_key], argv: [token])
                local token = ARGV[1] 
                local lock_key = KEYS[1]
  
                if redis.call("get", lock_key) == token then
                  return redis.call("del", lock_key)
                else
                  return 0
                end
              LUA
            end

            released == "1"
          end
        end
      end
    end
  end
end
