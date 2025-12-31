# frozen_string_literal: true

module Stoplight
  module Domain
    module TrafficControl
      # Strategies for determining when a Stoplight should change color to red.
      #
      # These strategies evaluate the current state and metrics of a Stoplight to decide
      # if traffic should be stopped (i.e., if the light should turn RED).
      #
      # @example Creating a custom strategy
      #   class ErrorRateStrategy < Stoplight::Domain::TrafficControl::Base
      #     def check_compatibility(config)
      #       if config.window_size.nil?
      #         incompatible("`window_size` should be set")
      #       else
      #         compatible
      #       end
      #     end
      #
      #     def stop_traffic?(config, metrics)
      #       total = metrics.successes + metrics.failures
      #       return false if total < 10 # Minimum sample size
      #
      #       error_rate = metrics.failures.fdiv(total)
      #       error_rate >= 0.5 # Stop traffic when error rate reaches 50%
      #     end
      #   end
      #
      # @abstract
      # @api private
      class Base
        # Checks if the strategy is compatible with the given Stoplight configuration.
        #
        # @param config [Stoplight::Domain::Config]
        # @return [Stoplight::Domain::CompatibilityResult]
        # :nocov:
        def check_compatibility(config)
          raise NotImplementedError
        end
        # :nocov:

        # Determines whether traffic should be stopped based on the Stoplight's
        # current state and metrics.
        #
        # @param config [Stoplight::Domain::Config]
        # @param metrics [Stoplight::Domain::MetricsSnapshot]
        # @return [Boolean] true if traffic should be stopped (rec), false otherwise (green)
        # :nocov:
        def stop_traffic?(config, metrics)
          raise NotImplementedError
        end
        # :nocov:

        # @param other [any]
        # @return [Boolean]
        def ==(other)
          other.is_a?(self.class)
        end

        # Returns a compatibility result indicating the strategy is compatible.
        #
        # @return [Stoplight::Domain::CompatibilityResult] A compatible result.
        private def compatible = CompatibilityResult.compatible

        # Returns a compatibility result indicating the strategy is incompatible.
        #
        # @param errors [Array<String>] The list of error messages describing incompatibility.
        # @return [Stoplight::Domain::CompatibilityResult] An incompatible result.
        private def incompatible(*errors) = CompatibilityResult.incompatible(*errors)
      end
    end
  end
end
