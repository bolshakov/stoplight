# frozen_string_literal: true

module Stoplight
  module Domain
    module Storage
      # Encapsulates metrics storage per light, per aggregation strategy
      #
      # @abstract
      class Metrics
        # Get metrics for the current light
        #
        # @return [Stoplight::Domain::Metrics]
        def metrics_snapshot
          raise NotImplementedError
        end

        # Tracks successful circuit breaker execution
        #
        # @return [void]
        def record_success
          raise NotImplementedError
        end

        # Tracks failed circuit breaker execution
        #
        # @param error [StandardError]
        # @return [void]
        def record_failure(error)
          raise NotImplementedError
        end

        # TODO: Actually this should also reset consecutive
        #     data_store.clear_windowed_metrics(config)
        #     data_store.clear_consecutive_counts(config)  # NEW: Clear consecutive too
        # also need to clear recovery metrics on each transition from yellow
        # def reset_window
        #
        # end
        # @return [void]
        def reset
          raise NotImplementedError
        end
      end
    end
  end
end
