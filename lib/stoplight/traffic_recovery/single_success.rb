# frozen_string_literal: true

module Stoplight
  module TrafficRecovery
    # A basic strategy that recovers traffic flow after a successful recovery probe.
    #
    # This strategy allows traffic to resume when a single successful probe
    # occurs after the Stoplight has been in red state. It's a simple "one success and we're back"
    # approach.
    #
    # @example Basic usage
    #   config = Stoplight::Light::Config.new(cool_off_time: 60)
    #   strategy = Stoplight::TrafficRecovery::SingleSuccess.new
    #
    # After the Stoplight turns red:
    # - The Stoplight will wait for the cool-off period (60 seconds)
    # - Then enter the recovery phase (YELLOW color)
    # - The first successful probe will resume normal traffic flow (green color)
    #
    class SingleSuccess < Base
      # @param config [Stoplight::Light::Config]
      # @param metadata [Stoplight::Metadata]
      # @return [String]
      def determine_color(config, metadata)
        recovery_started_at = metadata.recovery_started_at || metadata.recovery_scheduled_after
        last_success_at = metadata.last_success_at
        if last_success_at && recovery_started_at <= last_success_at
          Color::GREEN
        else
          Color::RED
        end
      end
    end
  end
end
