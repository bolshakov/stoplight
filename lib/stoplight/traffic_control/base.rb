# frozen_string_literal: true

module Stoplight
  module TrafficControl
    # Strategies for determining when a Stoplight should change color to red.
    #
    # These strategies evaluate the current state and metrics of a Stoplight to decide
    # if traffic should be stopped (i.e., if the light should turn RED).
    #
    # @example Creating a custom strategy
    #   class ErrorRateStrategy < Stoplight::TrafficControl::Base
    #     def stop_traffic?(config, metadata)
    #       total = metadata.successes + metadata.failures
    #       return false if total < 10 # Minimum sample size
    #
    #       error_rate = metadata.failures.fdiv(total)
    #       error_rate >= 0.5 # Stop traffic when error rate reaches 50%
    #     end
    #   end
    #
    # @abstract
    class Base
      # Determines whether traffic should be stopped based on the Stoplight's
      # current state and metrics.
      #
      # @param config [Stoplight::Light::Config]
      # @param metadata [Stoplight::Metadata]
      # @return [Boolean] true if traffic should be stopped (rec), false otherwise (green)
      def stop_traffic?(config, metadata)
        raise NotImplementedError
      end
    end
  end
end
