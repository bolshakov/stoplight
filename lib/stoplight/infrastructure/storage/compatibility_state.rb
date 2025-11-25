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
      class CompatibilityState < Domain::Storage::State
        # @!attribute data_store
        #   @return [Stoplight::Domain::DataStore]
        private attr_reader :data_store

        # @!attribute config
        #   @return [Stoplight::Domain::Config]
        private attr_reader :config

        # @param data_store [Stoplight::Domain::DataStore]
        # @param config [Stoplight::Domain::Config]
        def initialize(data_store:, config:)
          @data_store = data_store
          @config = config
        end

        # @return [Stoplight::Domain::StateSnapshot]
        def state_snapshot = data_store.get_state_snapshot(config)

        # @param state [String]
        # @return [String]
        def set_state(state) = data_store.set_state(config, state)

        # @param color [String]
        # @return [Boolean]
        def transition_to_color(color) = data_store.transition_to_color(config, color)

        # @return [void]
        def clear = data_store.delete_light(config)
      end
    end
  end
end
