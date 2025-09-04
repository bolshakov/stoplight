# frozen_string_literal: true

module Stoplight
  module TrafficRecovery
    # A conservative strategy that requires multiple consecutive successful probes
    # before resuming traffic flow.
    #
    # The strategy immediately returns to RED state if any failure occurs during
    # the recovery process, ensuring that only truly stable services resume
    # full traffic flow.
    #
    # @example Basic usage with 3 consecutive successes required
    #   config = Stoplight::Light::Config.new(
    #     cool_off_time: 60,
    #     recovery_threshold: 3
    #   )
    #   strategy = Stoplight::TrafficRecovery::ConsecutiveSuccesses.new
    #
    # Recovery behavior:
    # - After cool-off period, Stoplight enters YELLOW (recovery) state
    # - Requires 3 consecutive successful probes to transition to GREEN
    # - Any failure during recovery immediately returns to RED state
    # - Process repeats after another cool-off period
    #
    # Configuration requirements:
    # - `recovery_threshold`: Integer > 0, specifies required consecutive successes
    #
    # Failure behavior:
    # Unlike some circuit breaker implementations that tolerate occasional failures
    # during recovery, this strategy takes a zero-tolerance approach: any failure
    # during the recovery phase immediately transitions back to RED state. This
    # conservative approach prioritizes stability over recovery speed.
    #
    # @api private
    class ConsecutiveSuccesses < Base
      # @param config [Stoplight::Light::Config]
      # @return [Stoplight::Config::CompatibilityResult]
      def check_compatibility(config)
        if config.recovery_threshold <= 0
          incompatible("`recovery_threshold` should be bigger than 0")
        elsif !config.recovery_threshold.is_a?(Integer)
          incompatible("`recovery_threshold` should be an integer")
        else
          compatible
        end
      end

      # Determines if traffic should be resumed based on successes counts.
      #
      # @param config [Stoplight::Light::Config]
      # @param metadata [Stoplight::Metadata]
      # @return [TrafficRecovery::Decision]
      def determine_color(config, metadata)
        return TrafficRecovery::PASS if metadata.color != Color::YELLOW

        recovery_started_at = metadata.recovery_started_at || metadata.recovery_scheduled_after

        if metadata.last_error_at && metadata.last_error_at >= recovery_started_at
          TrafficRecovery::RED
        elsif [metadata.consecutive_successes, metadata.recovery_probe_successes].min >= config.recovery_threshold
          TrafficRecovery::GREEN
        else
          TrafficRecovery::YELLOW
        end
      end
    end
  end
end
