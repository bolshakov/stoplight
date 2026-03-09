# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Storage
      # Temporary adapter that bridges Domain::Storage::State to existing DataStore.
      #
      # This compatibility layer allows the state abstraction to be introduced
      # without breaking existing data store implementations. It delegates all
      # state operations to the data store's original methods.
      #
      # This adapter will be removed in a future versions once all
      # data stores have native state storage implementations.
      #
      # @example Creating state storage for a circuit
      #   state = CompatibilityState.new(
      #     data_store: redis_store,
      #     config: circuit_config
      #   )
      #   state.set_state(State::LOCKED_RED)
      #   snapshot = state.state_snapshot
      #
      class CompatibilityState
        def initialize(data_store:, config:)
          @data_store = data_store
          @config = config
        end

        def state_snapshot = data_store.get_state_snapshot(config)

        def set_state(state) = data_store.set_state(config, state)

        def transition_to_color(color) = data_store.transition_to_color(config, color)

        def clear = data_store.delete_light(config)

        private

        attr_reader :data_store
        attr_reader :config
      end
    end
  end
end
