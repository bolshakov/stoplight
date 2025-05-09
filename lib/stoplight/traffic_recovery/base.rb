# frozen_string_literal: true

module Stoplight
  module TrafficRecovery
    # Strategies for determining how to recover traffic flow through the Stoplight.
    # These strategies evaluate recovery metrics to decide which color the Stoplight should
    # transition to during the recovery process.
    #
    # @example Creating a custom traffic recovery strategy
    #   class GradualRecovery < Stoplight::TrafficRecovery::Base
    #     def initialize(min_success_rate: 0.8, min_samples: 100)
    #       @min_success_rate = min_success_rate
    #       @min_samples = min_samples
    #     end
    #
    #     def determine_color(config, metadata)
    #       total_probes = metadata.recovery_probe_successes + metadata.recovery_probe_failures
    #
    #       if total_probes < @min_samples
    #         return Color::YELLOW # Keep recovering, not enough samples
    #       end
    #
    #       success_rate = metadata.recovery_probe_successes.fdiv(total_probes)
    #       if success_rate >= @min_success_rate
    #         Color::GREEN # Recovery successful
    #       elsif success_rate <= 0.2
    #         Color::RED # Recovery failed, too many errors
    #       else
    #         Color::YELLOW # Continue recovery
    #       end
    #     end
    #   end
    #
    # @abstract
    class Base
      # Determines the appropriate recovery state based on the Stoplight's
      # current metrics and recovery progress.
      #
      # @param config [Stoplight::Light::Config]
      # @param metadata [Stoplight::Metadata]
      # @return [String] One of the Stoplight::Color constants:
      #   - Stoplight::Color::RED: Recovery failed, block all traffic
      #   - Stoplight::Color::YELLOW: Continue recovery process
      #   - Stoplight::Color::GREEN: Recovery successful, return to normal traffic flow
      def determine_color(config, metadata)
        raise NotImplementedError
      end
    end
  end
end
