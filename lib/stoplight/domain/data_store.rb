# frozen_string_literal: true

module Stoplight
  module Domain
    # @abstract
    # :nocov:
    class DataStore
      METRICS_RETENTION_TIME = 60 * 60 * 24 # 1 day

      # Retrieves the names of all lights stored in the data store.
      #
      # @return [Array<String>] An array of light names.
      def names
        raise NotImplementedError
      end

      # Retrieves metrics for a specific light configuration.
      #
      # @param config [Stoplight::Domain::Config]
      # @return [Stoplight::Domain::Metrics]
      def get_metrics(config)
        raise NotImplementedError
      end

      # Retrieves recovery metrics for a specific light configuration.
      #
      # @param config [Stoplight::Domain::Config]
      # @return [Stoplight::Domain::Metrics]
      def get_recovery_metrics(config)
        raise NotImplementedError
      end

      # Retrieves State Snapshot for a specific light configuration.
      #
      # @param config [Stoplight::Domain::Config] The light configuration.
      # @return [Stoplight::Domain::StateSnapshot]
      def get_state_snapshot(config)
        raise NotImplementedError
      end

      # Clears windowed metrics (successes/errors) to prevent
      # stale failures from before recovery from affecting post-recovery decisions.
      # Consecutive counts are intentionally preserved as they track current streaks.
      #
      # @param config [Stoplight::Domain::Config] The light configuration.
      # @return [void]
      def clear_metrics(config)
        raise NotImplementedError
      end

      def clear_recovery_metrics(config)
        raise NotImplementedError
      end

      # Records a failure for a specific light configuration.
      #
      # @param config [Stoplight::Domain::Config]
      # @param exception [Exception]
      # @return [void]
      def record_failure(config, exception)
        raise NotImplementedError
      end

      # Records a success for a specific light configuration.
      #
      # @param config [Stoplight::Domain::Config]
      # @return [void]
      def record_success(config)
        raise NotImplementedError
      end

      # Records a failed recovery probe for a specific light configuration.
      #
      # @param config [Stoplight::Domain::Config]
      # @param failure [Failure]
      # @return [void]
      def record_recovery_probe_failure(config, failure)
        raise NotImplementedError
      end

      # Records a successful recovery probe for a specific light configuration.
      #
      # @param config [Stoplight::Domain::Config]
      # @return [void]
      def record_recovery_probe_success(config)
        raise NotImplementedError
      end

      # Sets the state of a specific light configuration.
      #
      # @param config [Stoplight::Domain::Config]
      # @param state [String] The new state to set.
      # @return [String] The state that was set.
      def set_state(config, state)
        raise NotImplementedError
      end

      # A lock used to linearize recovery run executions. The use of this lock
      # guarantees that only one instance of Light is trying to perform recovery
      # at a time, preventing Thundering Herd problem and race conditions during recovery.
      #
      # It yields locked data store so operation withing the block, could use
      # this data store instance.
      # @param config [Stoplight::Domain::Config]
      # @yieldparam [Stoplight::Domain::DataStore]
      #   Yields data store used through the whole recovery process
      #
      # @example
      #   data_store.with_recovery_lock do |locked_store|
      #     locked_store.record_failure(config, failure)
      #   end
      #
      def with_recovery_lock(config)
        raise NotImplementedError
      end

      # Transitions the Stoplight to the specified color.
      #
      # This method performs a color transition operation that works across distributed instances
      # of the light. It ensures that in a multi-instance environment, only one instance
      # is considered the "first" to perform the transition (and therefore responsible for
      # triggering notifications).
      #
      # @param config [Stoplight::Domain::Config]
      # @param color [String] The target color/state to transition to.
      #   Should be one of Stoplight::Color::GREEN, Stoplight::Color::YELLOW, or Stoplight::Color::RED.
      #
      # @return [Boolean] Returns +true+ if this instance was the first to perform this specific transition
      #   (and should therefore trigger notifications). Returns +false+ if another instance already
      #   initiated this transition.
      #
      # @note In distributed environments with multiple instances, race conditions can occur when instances
      #   attempt conflicting transitions simultaneously (e.g., one instance tries to transition from
      #   YELLOW to GREEN while another tries YELLOW to RED). The implementation handles this, but
      #   be aware that the last operation may determine the final color of the light.
      #
      def transition_to_color(config, color)
        raise NotImplementedError
      end

      # Deletes metadata (and related persistent state) for the given light.
      #
      # Implementations may choose to only remove metadata; metrics may expire via TTL.
      #
      # @param config [Stoplight::Domain::Config]
      # @return [void]
      def delete_light(config)
        raise NotImplementedError
      end
    end
    # :nocov:
  end
end
