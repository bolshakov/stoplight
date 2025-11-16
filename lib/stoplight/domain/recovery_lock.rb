# frozen_string_literal: true

module Stoplight
  module Domain
    # Serializes recovery probe executions to prevent race conditions.
    #
    # When a circuit enters YELLOW (half-open) state, multiple processes
    # may simultaneously attempt to send recovery probes. This creates
    # three problems:
    #
    # 1. Thundering Herd: All processes send probes simultaneously,
    #    overwhelming the recovering service
    # 2. Check-Then-Act Race: Process A reads metrics, Process B updates
    #    metrics, Process A makes transition based on stale data
    # 3. Last-Write-Wins: Conflicting transitions race to data store,
    #    network timing determines winner (not correctness)
    #
    # The RecoveryLock ensures only ONE process holds the lock during:
    #   1. Probe execution
    #   2. Result recording
    #   3. Metrics reading
    #   4. State transition decision
    #
    # All operations use the SAME pinned data store instance to prevent
    # mid-operation failover from one type of data store to another.
    #
    # @example Usage in YellowRunStrategy
    #   recovery_lock.with_lock(light_name) do |pinned_store|
    #     outcome = execute_probe(&block)
    #     record_result(outcome, pinned_store)
    #     metrics = read_metrics(pinned_store)
    #     transition_if_needed(metrics, pinned_store)
    #   end
    #
    # @abstract
    class RecoveryLock
      # Acquires lock, yields pinned data store, ensures release.
      #
      # @param light_name [String]
      # @yieldparam [Stoplight::Domain::DataStore]
      #   The pinned data store for all recovery operations
      # @return [Boolean] true if lock acquired and block executed,
      #   false if lock unavailable
      def with_lock(light_name)
        raise NotImplementedError
      end
    end
  end
end
