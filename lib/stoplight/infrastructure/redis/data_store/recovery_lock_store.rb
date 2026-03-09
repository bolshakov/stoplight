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
          def initialize(redis:, lock_timeout:, scripting:)
            @redis = redis
            @lock_timeout = lock_timeout
            @scripting = scripting
          end

          def acquire_lock(light_name)
            recovery_lock = RecoveryLockToken.new(light_name:)

            acquired = !!redis.then do |client|
              client.set(recovery_lock.lock_key, recovery_lock.token, nx: true, px: lock_timeout)
            end

            recovery_lock if acquired
          end

          def release_lock(recovery_lock)
            scripting.call(
              :release_lock,
              keys: [recovery_lock.lock_key], args: [recovery_lock.token]
            )
          end

          protected

          attr_reader :redis
          attr_reader :lock_timeout
          attr_reader :scripting
        end
      end
    end
  end
end
