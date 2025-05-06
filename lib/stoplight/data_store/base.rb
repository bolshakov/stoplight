# frozen_string_literal: true

module Stoplight
  module DataStore
    # @abstract
    class Base
      # Retrieves the names of all lights stored in the data store.
      #
      # @return [Array<String>] An array of light names.
      def names
        raise NotImplementedError
      end

      # Retrieves metadata for a specific light configuration.
      #
      # @param config [Stoplight::Light::Config] The light configuration.
      # @return [Stoplight::DataStore::Metadata] The metadata associated with the light.
      def get_metadata(config)
        raise NotImplementedError
      end

      # Records a failure for a specific light configuration.
      #
      # @param config [Stoplight::Light::Config] The light configuration.
      # @param failure [Failure] The failure to record.
      # @return [void]
      def record_failure(config, failure)
        raise NotImplementedError
      end

      # Records a success for a specific light configuration.
      #
      # @param config [Stoplight::Light::Config] The light configuration.
      # @param request_id [String] The unique identifier for the request
      # @param request_time [Time] The time of the request
      # @return [void]
      def record_success(config, request_id:, request_time:)
        raise NotImplementedError
      end

      # Records a failed recovery probe for a specific light configuration.
      #
      # @param config [Stoplight::Light::Config] The light configuration.
      # @param failure [Failure] The failure to record.
      # @return [void]
      def record_recovery_probe_failure(config, failure)
        raise NotImplementedError
      end

      # Records a successful recovery probe for a specific light configuration.
      #
      # @param config [Stoplight::Light::Config] The light configuration.
      # @param request_id [String] The unique identifier for the request
      # @param request_time [Time] The time of the request
      # @return [void]
      def record_recovery_probe_success(config, request_id:, request_time:)
        raise NotImplementedError
      end

      # Retrieves the state of a specific light configuration.
      #
      # @param config [Stoplight::Light::Config] The light configuration.
      # @return [String] The current state of the light.
      def get_state(config)
        raise NotImplementedError
      end

      # Sets the state of a specific light configuration.
      #
      # @param config [Stoplight::Light::Config] The light configuration.
      # @param state [String] The new state to set.
      # @return [String] The state that was set.
      def set_state(config, state)
        raise NotImplementedError
      end

      # Clears the state of a specific light configuration.
      #
      # @param config [Stoplight::Light::Config] The light configuration.
      # @return [String] The cleared state.
      def clear_state(config)
        raise NotImplementedError
      end

      # Transitions the Stoplight to the specified color (state).
      #
      # This method performs a state transition operation that works across distributed instances
      # of the circuit breaker. It ensures that in a multi-instance environment, only one instance
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
      #   be aware that the last operation may determine the final state.
      #
      def transition_to_color(config, color)
        raise NotImplementedError
      end
    end
  end
end
