# frozen_string_literal: true

module Stoplight
  module TrafficControl
    # A strategy that stops the traffic based on error rate.
    #
    # @example
    #   traffic_control = Stoplight::TrafficControlStrategy::ErrorRate.new
    #   config = Stoplight::Light::Config.new(threshold: 0.6, window_size: 300, traffic_control:)
    #
    # Will switch to red if 60% error rate reached within the 5-minute (300 seconds) sliding window.
    # By default this traffic control strategy starts evaluating only after 10 requests have been made. You can
    # adjust this by passing a different value for `min_requests` when initializing the strategy.
    #
    #   traffic_control = Stoplight::TrafficControlStrategy::ErrorRate.new(min_requests: 100)
    #
    # @api private
    class ErrorRate < Base
      # @!attribute min_requests
      #   @return [Integer]
      attr_reader :min_requests

      # @param min_requests [Integer] Minimum number of requests before traffic control is applied.
      #   until this number of requests is reached, the error rate will not be considered.
      def initialize(min_requests: 10)
        @min_requests = min_requests
      end

      # @param config [Stoplight::Light::Config]
      # @return [Stoplight::Config::CompatibilityResult]
      def check_compatibility(config)
        if config.window_size.nil?
          incompatible("`window_size` should be set")
        elsif config.threshold < 0 || config.threshold > 1
          incompatible("`threshold` should be between 0 and 1")
        else
          compatible
        end
      end

      # @param config [Stoplight::Light::Config]
      # @param metadata [Stoplight::Metadata]
      # @return [Boolean]
      def stop_traffic?(config, metadata)
        metadata.requests >= min_requests && metadata.error_rate >= config.threshold
      end
    end
  end
end
