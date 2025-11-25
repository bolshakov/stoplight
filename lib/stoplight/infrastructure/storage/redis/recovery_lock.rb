# frozen_string_literal: true

require "forwardable"

module Stoplight
  module Infrastructure
    module Storage
      module Redis
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
        class RecoveryLock < Domain::Storage::RecoveryLock
          extend Forwardable

          def_delegator "Stoplight::Infrastructure::DataStore::Redis", :key

          # @!attribute config
          #   @return [Stoplight::Domain::Config]
          private attr_reader :config

          # @!attribute redis
          #   @return [::Redis | ConnectionPool<::Redis>]
          private attr_reader :redis

          # @!attribute scripting
          #   @return [Stoplight::Infrastructure::DataStore::Redis::Scripting]
          private attr_reader :scripting

          def initialize(config:, redis:, scripting:)
            @config = config
            @redis = redis
            @scripting = scripting
          end

          def acquire_lock
            recovery_lock = RecoveryLockToken.new

            acquired = redis.then do |client|
              client.set(lock_key, recovery_lock.token, nx: true, px: lock_timeout)
            end

            recovery_lock if acquired
          end

          # @param recovery_lock [Stoplight::Infrastructure::DataStore::Redis::RecoveryLockToken]
          # @return [void]
          def release_lock(recovery_lock)
            scripting.call(
              :release_lock,
              keys: [lock_key], args: [recovery_lock.token]
            )
          end

          private def lock_key = key(:locks, :recovery, config.name)

          private def lock_timeout = config.cool_off_time_in_milliseconds
        end
      end
    end
  end
end
