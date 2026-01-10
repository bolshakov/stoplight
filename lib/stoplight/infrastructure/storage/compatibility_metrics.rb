# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Storage
      # Temporary adapter that bridges Domain::Storage::Metrics to existing DataStore.
      #
      # This compatibility layer allows the metrics abstraction to be introduced
      # without breaking existing data store implementations. It delegates all
      # operations to the data store's original methods.
      #
      # This class will be removed in a future versions once all data stores
      # have native metrics implementations.
      #
      # @example Creating metrics for a circuit
      #   metrics = CompatibilityMetrics.new(
      #     data_store: redis_store,
      #     config: config
      #   )
      #   metrics.record_success
      #
      class CompatibilityMetrics
        attr_reader :data_store
        attr_reader :config

        def initialize(data_store:, config:)
          @data_store = data_store
          @config = config
        end

        def metrics_snapshot = data_store.get_metrics(config)

        def record_success = data_store.record_success(config)

        def record_failure(error) = data_store.record_failure(config, error)

        def clear = data_store.clear_metrics(config)
      end
    end
  end
end
