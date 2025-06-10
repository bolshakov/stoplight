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
    #     def check_compatibility(config)
    #       if config.window_size.nil?
    #         incompatible("`window_size` should be set")
    #       else
    #         compatible
    #       end
    #     end
    #
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
    # @api private
    class Base
      # Checks if the strategy is compatible with the given Stoplight configuration.
      #
      # @param config [Stoplight::Light::Config]
      # @return [Stoplight::TrafficControl::CompatibilityResult]
      def check_compatibility(config)
        raise NotImplementedError
      end

      # Determines whether traffic should be stopped based on the Stoplight's
      # current state and metrics.
      #
      # @param config [Stoplight::Light::Config]
      # @param metadata [Stoplight::Metadata]
      # @return [Boolean] true if traffic should be stopped (rec), false otherwise (green)
      def stop_traffic?(config, metadata)
        raise NotImplementedError
      end

      # @param other [any]
      # @return [Boolean]
      def ==(other)
        other.is_a?(self.class)
      end

      # Returns a compatibility result indicating the strategy is compatible.
      #
      # @return [Stoplight::Config::CompatibilityResult] A compatible result.
      private def compatible = Config::CompatibilityResult.compatible

      # Returns a compatibility result indicating the strategy is incompatible.
      #
      # @param errors [Array<String>] The list of error messages describing incompatibility.
      # @return [Stoplight::Config::CompatibilityResult] An incompatible result.
      private def incompatible(*errors) = Config::CompatibilityResult.incompatible(*errors)
    end
  end
end
