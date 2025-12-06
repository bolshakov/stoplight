# frozen_string_literal: true

module Stoplight
  module Domain
    module Storage
      # Encapsulates recovery lock management for coordinating recovery probes.
      #
      # When a circuit enters YELLOW state (half-open), it begins sending
      # "recovery probes" - test requests to check if the protected service
      # has recovered. In distributed deployments with multiple instances,
      # recovery locks ensure only ONE instance sends probes at a time.
      #
      # Without coordination, all instances would simultaneously:
      # 1. Detect the circuit is YELLOW
      # 2. Send recovery probes to the struggling service
      # 3. Potentially overwhelm it with "test" traffic
      #
      # Lock Lifecycle:
      #
      #   Instance A: acquire_lock -> probe -> release_lock
      #   Instance B: acquire_lock -> nil (already held) -> skip probe
      #   Instance C: acquire_lock -> nil (already held) -> skip probe
      #
      # Lock Semantics:
      # - Returns +nil+ if lock is already held. Never blocks waiting for lock availability
      # - Locks must automatically expire when persisted storage is used
      # - Failed releases are acceptable (timeout provides safety)
      #
      # @abstract
      # @see Stoplight::Domain::Strategies::YellowRunStrategy
      class RecoveryLock
        # Attempts to acquire recovery lock for exclusive probe execution.
        #
        # This method tries to acquire a lock that serializes recovery probe
        # execution across multiple instances. If the lock is already held by
        # another instance, returns +nil+ immediately without blocking.
        #
        # @return [Stoplight::Domain::RecoveryLockToken, nil]
        #   - +RecoveryLockToken+: Lock acquired, caller should send probe
        #   - +nil+: Lock unavailable, another instance is probing
        #
        def acquire_lock = raise NotImplementedError

        # Releases a previously acquired lock.
        #
        # This method releases the lock token returned by +#acquire_lock+,
        # allowing other instances to acquire it. Release should be called
        # in an ensure block to guarantee cleanup even if probe fails.
        #
        # @param lock [Stoplight::Domain::RecoveryLockToken] The token returned by +#acquire_lock+
        # @return [void]
        def release_lock(lock) = raise NotImplementedError
      end
    end
  end
end
