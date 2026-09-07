# frozen_string_literal: true

module Stoplight
  module Wiring
    # Validates that traffic control and recovery strategies are
    # compatible with the provided configuration.
    #
    # Different strategies have different configuration requirements:
    # - ErrorRate requires window_size and threshold ∈ [0,1]
    # - ConsecutiveErrors requires threshold > 0
    # - ConsecutiveSuccesses requires recovery_threshold > 0
    #
    # @raise [Stoplight::Error::ConfigurationError] if incompatible
    class ConfigCompatibilityValidator
      private attr_reader :config

      class << self
        def call(config:) = new(config:).call
      end

      def initialize(config:)
        @config = config
      end

      def call
        validate_window_size!
        validate_traffic_control!
        validate_traffic_recovery!
        config
      end

      # A window shorter than one bucket cannot be measured, and a fractional one silently
      # rounds to a different span than requested.
      private def validate_window_size!
        window_size = config.window_size
        return if window_size.nil?
        return if window_size.is_a?(Integer) && window_size >= 1

        raise Error::ConfigurationError,
          "`window_size` should be a whole number of seconds, at least 1, got #{window_size.inspect}",
          ExternalCaller.backtrace
      end

      private def validate_traffic_control!
        traffic_control = config.traffic_control
        traffic_control.check_compatibility(config).then do |compatibility_result|
          if compatibility_result.incompatible?
            raise Error::ConfigurationError,
              "#{traffic_control} incompatible with config: #{compatibility_result.error_messages}",
              ExternalCaller.backtrace
          end
        end
      end

      def validate_traffic_recovery!
        traffic_recovery = config.traffic_recovery
        traffic_recovery.check_compatibility(config).then do |compatibility_result|
          if compatibility_result.incompatible?
            raise Error::ConfigurationError,
              "#{traffic_recovery} incompatible with config: #{compatibility_result.error_messages}",
              ExternalCaller.backtrace
          end
        end
      end
    end
  end
end
