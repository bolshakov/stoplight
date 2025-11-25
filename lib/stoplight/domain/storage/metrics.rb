# frozen_string_literal: true

module Stoplight
  module Domain
    module Storage
      # Encapsulates metrics storage for circuit breaker execution tracking.
      #
      # This abstraction isolates metrics collection and retrieval from the
      # broader data store concerns, enabling:
      # - Purpose-built implementations optimized for time-series data
      # - Independent scaling and optimization of metrics vs. state storage
      # - Clearer separation between "what happened" (metrics) and "what to do" (state)
      #
      # Lifecycle: A Metrics instance is scoped to a single circuit breaker
      # configuration. Each circuit gets its own metrics store instance,
      # allowing different circuits to use different storage strategies.
      #
      # @abstract
      class Metrics
        # Retrieves a snapshot of current metrics for decision-making.
        #
        # @return [Stoplight::Domain::Metrics]
        def metrics_snapshot = raise NotImplementedError

        # Records a successful circuit breaker execution
        #
        # @return [void]
        def record_success = raise NotImplementedError

        # Records a failed circuit breaker execution
        #
        # @param error [StandardError]
        # @return [void]
        def record_failure(error) = raise NotImplementedError

        # Clears all metrics for this circuit
        # @return [void]
        def clear = raise NotImplementedError
      end
    end
  end
end
