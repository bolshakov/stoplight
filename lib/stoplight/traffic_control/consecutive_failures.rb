# frozen_string_literal: true

module Stoplight
  module TrafficControl
    # A strategy that stops the traffic based on consecutive failures number.
    #
    # This strategy implements two distinct behaviors based on whether a window size
    # is configured:
    #
    # 1. When window_size is set: The Stoplight turns red when the total number of
    #    failures within the window reaches the threshold.
    #
    # 2. When window_size is not set: The Stoplight turns red when consecutive failures
    #    reach the threshold.
    #
    # @example With window-based configuration
    #   config = Stoplight::Light::Config.new(threshold: 5, window_size: 60)
    #   strategy = Stoplight::TrafficControlStrategy::ConsecutiveFailures.new
    #
    # Will switch to red if 5 consecutive failures occur within the 60-second window
    #
    # @example With total number of consecutive failures configuration
    #   config = Stoplight::Light::Config.new(threshold: 5, window_size: nil)
    #   strategy = Stoplight::TrafficControlStrategy::ConsecutiveFailures.new
    #
    # Will switch to red only if 5 consecutive failures occur regardless of the time window
    # @api private
    class ConsecutiveFailures < Base
      # Determines if traffic should be stopped based on failure counts.
      #
      # @param config [Stoplight::Light::Config]
      # @param metadata [Stoplight::Metadata]
      # @return [Boolean] true if failures have reached the threshold, false otherwise
      def stop_traffic?(config, metadata)
        if config.window_size
          [metadata.consecutive_failures, metadata.failures].min >= config.threshold
        else
          metadata.consecutive_failures >= config.threshold
        end
      end
    end
  end
end
