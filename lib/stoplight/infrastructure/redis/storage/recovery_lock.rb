# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Redis
      module Storage
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
        class RecoveryLock
          def initialize(config:, redis:, scripting:, key_space:)
            @config = config
            @redis = redis
            @scripting = scripting
            @key_space = key_space
          end

          def acquire_lock
            recovery_lock = Domain::Storage::RecoveryLockToken.new

            acquired = redis.then do |client|
              client.set(lock_key, recovery_lock.token, nx: true, px: lock_timeout)
            end

            recovery_lock if acquired
          end

          # @param recovery_lock [Stoplight::Infrastructure::Redis::DataStore::RecoveryLockToken]
          # @return [void]
          def release_lock(recovery_lock)
            scripting.call(
              "recovery_lock/release_lock",
              keys: [lock_key], args: [recovery_lock.token]
            )
          end

          private

          attr_reader :config
          attr_reader :redis
          attr_reader :scripting
          attr_reader :key_space

          def lock_key = key_space.key(:locks, :recovery)
          def lock_timeout = config.cool_off_time_in_milliseconds
        end
      end
    end
  end
end
