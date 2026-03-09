# frozen_string_literal: true

module Stoplight
  module Wiring
    # Assembles a StorageSet from a backend, selecting windowed or unbounded metrics.
    #
    # StorageSetBuilder is the single point where the windowed/unbounded decision
    # is made. All other storage components (state, recovery lock, recovery metrics)
    # are backend-specific but mode-independent.
    #
    # @example Windowed metrics (error rate tracking)
    #   builder = StorageSetBuilder.new(backend: redis_backend, windowed: true)
    #   storage = builder.build
    #   storage.metrics_store #=> FailSafe<WindowMetrics>
    #
    # @example Unbounded metrics (consecutive error tracking)
    #   builder = StorageSetBuilder.new(backend: memory_backend, windowed: false)
    #   storage = builder.build
    #   storage.metrics_store #=> UnboundedMetrics
    #
    # @see DataStoreBackend
    # @see StorageSet
    # @api private
    class StorageSetBuilder
      attr_reader :backend
      attr_reader :windowed

      def initialize(backend:, windowed:)
        @backend = backend
        @windowed = windowed
      end

      def build
        StorageSet.new(
          metrics_store:,
          recovery_metrics_store: backend.recovery_metrics_store,
          state_store: backend.state_store,
          recovery_lock_store: backend.recovery_lock_store
        )
      end

      private def metrics_store
        if windowed
          backend.windowed_metrics_store
        else
          backend.unbounded_metrics_store
        end
      end
    end
  end
end
