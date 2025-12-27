# frozen_string_literal: true

module Stoplight
  module Wiring
    class LightFactory
      # Validates that traffic control and recovery strategies are
      # compatible with the provided configuration.
      #
      # Different strategies have different configuration requirements:
      # - ErrorRate requires window_size and threshold ∈ [0,1]
      # - ConsecutiveErrors requires threshold > 0
      # - ConsecutiveSuccesses requires recovery_threshold > 0
      #
      # @raise [Stoplight::Error::ConfigurationError] if incompatible
      class CompatibilityValidator
        # @dynamic dependencies
        private attr_reader :dependencies
        # @dynamic config
        private attr_reader :config

        class << self
          def call(config, dependencies) = new(config, dependencies).call
        end

        def initialize(config, dependencies)
          @config = config
          @dependencies = dependencies
        end

        def call
          validate_traffic_control!
          validate_traffic_recovery!
        end

        private def validate_traffic_control!
          traffic_control = dependencies.fetch(:traffic_control)
          traffic_control.check_compatibility(config).then do |compatibility_result|
            if compatibility_result.incompatible?
              raise Domain::Error::ConfigurationError,
                "#{traffic_control.class.name} incompatible with config: #{compatibility_result.error_messages}",
                caller(8)
            end
          end
        end

        def validate_traffic_recovery!
          traffic_recovery = dependencies.fetch(:traffic_recovery)
          traffic_recovery.check_compatibility(config).then do |compatibility_result|
            if compatibility_result.incompatible?
              raise Domain::Error::ConfigurationError,
                "#{traffic_recovery.class.name} incompatible with config: #{compatibility_result.error_messages}",
                caller(8)
            end
          end
        end
      end
    end
  end
end
