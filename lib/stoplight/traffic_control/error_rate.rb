# frozen_string_literal: true

require_relative "base"

module Stoplight
  module TrafficControl
    # A strategy that stops traffic when the error rate exceeds a threshold.
    #
    # Usage: Pass as a traffic control strategy to a Light.
    #
    # @example
    #   # For error rate strategy, threshold should be between 0.0 and 1.0
    #   strategy = Stoplight::TrafficControl::ErrorRate.new(min_sample_size: 20)
    #   light = Stoplight::Light.new('my-light', ...) { ... }
    #   light.traffic_control_strategy = strategy
    class ErrorRate < Base
      def initialize(min_sample_size: 20)
        @min_sample_size = min_sample_size
      end

      # Determines if traffic should be stopped based on error rate.
      # @param config [Stoplight::Light::Config]
      # @param metadata [Stoplight::Metadata]
      # @return [Boolean] true if error rate exceeds threshold, false otherwise
      def stop_traffic?(config, metadata)
        threshold = config.threshold
        unless threshold.is_a?(Numeric) && threshold > 0.0 && threshold < 1.0
          raise ArgumentError, "threshold for ErrorRate must be a float between 0.0 and 1.0"
        end
        total = (metadata.successes || 0) + (metadata.failures || 0)
        return false if total < @min_sample_size
        error_rate = (metadata.failures || 0).fdiv(total)
        error_rate >= threshold
      end

      def ==(other)
        super &&
          other.instance_variable_get(:@min_sample_size) == @min_sample_size
      end
    end
  end
end
