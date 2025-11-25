# frozen_string_literal: true

module Stoplight
  module Domain
    module Storage
      # Encapsulates circuit breaker state storage.
      #
      # State management handles the current operational mode of a circuit breaker:
      # - Color (GREEN/YELLOW/RED) - whether the circuit is open or closed
      # - Lock state (LOCKED_GREEN/LOCKED_RED/UNLOCKED) - manual overrides
      # - State transitions - tracking color changes for notifications #
      #
      # State requires stronger consistency than metrics because:
      # - Multiple instances must agree on circuit color
      # - Race conditions during transitions must be handled
      # - Lock states must be immediately visible across instances
      #
      # @abstract
      # @see Stoplight::Domain::Storage::Metrics
      class State
        # Retrieves current state snapshot for decision-making.
        #
        # The snapshot is an immutable view of the circuit's current state,
        # including its color and lock status. This method is called on every
        # circuit breaker invocation to determine whether to allow traffic.
        #
        # This is called on every request, so implementations should be fast.
        #
        # @return [Stoplight::Domain::StateSnapshot]
        def state_snapshot = raise NotImplementedError

        # Sets the lock state of the circuit.
        #
        # Locks allow manual override of circuit behavior:
        # - LOCKED_GREEN: Force circuit closed (allow all traffic)
        # - LOCKED_RED: Force circuit open (block all traffic)
        # - UNLOCKED: Follow normal circuit breaker rules
        #
        # Lock states take precedence over color states. A locked circuit
        # ignores failure thresholds and stays in the locked state until
        # explicitly unlocked.
        #
        # Use Cases:
        # - Emergency traffic control during incidents
        # - Maintenance windows (lock RED to prevent traffic)
        # - Gradual rollout (lock GREEN during testing)
        #
        # @param state [String] The new state to set.
        # @return [String] The state that was set.
        def set_state(state) = raise NotImplementedError

        # Transitions the Stoplight to the specified color.
        #
        # This method performs a color transition operation that works across distributed instances
        # of the light. It ensures that in a multi-instance environment, only one instance
        # is considered the "first" to perform the transition (and therefore responsible for
        # triggering notifications).
        #
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
        def transition_to_color(color) = raise NotImplementedError

        # Clears all state data for this circuit.
        #
        # This removes the circuit from storage entirely, resetting it to
        # default (unlocked, green) state. The next invocation will start
        # with fresh state.
        #
        # @note This does NOT clear metrics. If you want to fully
        # reset a circuit, clear both state and metrics stores.
        #
        # @return [void]
        def clear = raise NotImplementedError
      end
    end
  end
end
