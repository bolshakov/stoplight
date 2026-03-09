# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Storage
      # When a circuit is RED (open), Stoplight periodically sends "recovery probes"
      # to test whether the protected service has recovered. These test requests have
      # different semantics than normal requests and their metrics are tracked separately.
      #
      # Like +CompatibilityMetrics+, this adapter will be replaced with purpose-built
      # recovery metrics implementations (e.g., +ConsecutiveSuccessMetrics+) once the
      # metrics extraction is complete.
      #
      # @example Recovery probe flow
      #   # Circuit is RED, start probing
      #   recovery_metrics = CompatibilityRecoveryMetrics.new(
      #     data_store: redis_store,
      #     config: circuit_config
      #   )
      #
      #   recovery_metrics.record_success
      #   recovery_metrics.metrics_snapshot # => 1 success, 0 failures
      #
      class CompatibilityRecoveryMetrics
        def initialize(data_store:, config:)
          @data_store = data_store
          @config = config
        end

        def metrics_snapshot = data_store.get_recovery_metrics(config)

        # Tracks successful circuit breaker execution
        def record_success = data_store.record_recovery_probe_success(config)

        # Tracks failed circuit breaker execution
        def record_failure(error) = data_store.record_recovery_probe_failure(config, error)

        def clear = data_store.clear_recovery_metrics(config)

        private

        attr_reader :data_store
        attr_reader :config
      end
    end
  end
end
