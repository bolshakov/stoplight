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
      #
      # @api private
      class ErrorRate
        NAME = :error_rate

        MIN_REQUESTS = 100
        private_constant :MIN_REQUESTS

        def initialize
        end

        def check_compatibility(config)
          if config.window_size.nil?
            CompatibilityResult.incompatible("`window_size` should be set")
          elsif !config.threshold.is_a?(Numeric)
            CompatibilityResult.incompatible("`threshold` should be a number")
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

          requests >= MIN_REQUESTS && error_rate >= config.threshold
        end

        def name = NAME.to_s

        def ==(other)
          other.is_a?(self.class)
        end

        def eql?(other)
          self == other
        end

        def hash = self.class.hash
      end
    end
  end
end
