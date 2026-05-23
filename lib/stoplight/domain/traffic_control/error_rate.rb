# frozen_string_literal: true

module Stoplight
  module Domain
    module TrafficControl
      # A strategy that stops the traffic based on error rate.
      #
      # @example
      #   traffic_control = Stoplight::Domain::TrafficControl::ErrorRate.new
      #   config = Stoplight::Domain::Config.new(threshold: 0.6, window_size: 300, traffic_control:)
      #
      # Will switch to red if 60% error rate reached within the 5-minute (300 seconds) sliding window.
      # By default this traffic control strategy starts evaluating only after 10 requests have been made. You can
      # adjust this by passing a different value for `min_requests` when initializing the strategy.
      #
      #   traffic_control = Stoplight::Domain::TrafficControl::ErrorRate.new(min_requests: 100)
      #
      # @api private
      class ErrorRate
        # @param min_requests Minimum number of requests before traffic control is applied.
        #   until this number of requests is reached, the error rate will not be considered.
        def initialize(min_requests: 10)
          @min_requests = min_requests
        end

        def check_compatibility(config)
          if config.window_size.nil?
            CompatibilityResult.incompatible("`window_size` should be set")
          elsif config.threshold < 0 || config.threshold > 1
            CompatibilityResult.incompatible("`threshold` should be between 0 and 1")
          else
            CompatibilityResult.compatible
          end
        end

        def stop_traffic?(config, metrics)
          error_rate = metrics.error_rate
          requests = metrics.requests

          raise ArgumentError, "accepts only windowed metrics" if error_rate.nil? || requests.nil?

          requests >= min_requests && error_rate >= config.threshold
        end

        def ==(other)
          other.is_a?(self.class) && min_requests == other.min_requests
        end

        def hash = [self.class, @min_requests].hash

        protected

        attr_reader :min_requests
      end
    end
  end
end
