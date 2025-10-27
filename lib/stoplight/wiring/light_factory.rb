# frozen_string_literal: true

module Stoplight
  module Wiring
    # Concrete factory for building +Stoplight::Light++ instances with full dependency wiring.
    #
    # This factory implements the +Stoplight::Domain::LightFactory+ protocol. It knows how to:
    #   1. Parse and transform user-provided settings
    #   2. Wire together all Light dependencies using a DI container
    #   3. Validate configuration compatibility
    #   4. Construct fully-functional Light instances
    #
    # @see Stoplight::Domain::LightFactory
    # @see Stoplight()
    # @api private

    class LightFactory < Domain::LightFactory
      # @!attribute [r] container
      #   The dependency injection container holding all component configurations.
      #   Contains config, data_store, notifiers, strategies, etc.
      #   @return [Stoplight::Wiring::Container]
      protected attr_reader :container

      # @param container [Stoplight::Wiring::Container]
      def initialize(container)
        @container = container
      end

      # @param settings [Hash] Settings to override in the new factory
      #   @see Stoplight()
      # @return [Stoplight::Wiring::LightFactory]
      # @see Stoplight()
      def with(**settings)
        transformed_settings = transform_settings(settings)
        config_settings = extract_config_settings(transformed_settings)
        dependency_settings = extract_dependency_settings(transformed_settings)

        validate_settings!(transformed_settings, config_settings, dependency_settings)

        new_config = container.resolve(:config).with(**config_settings)
        new_container = container.with(config: new_config, **dependency_settings)

        self.class.new(new_container)
      end

      # Builds a fully-configured Light instance.
      #
      # The method resolves all dependencies from the container and constructs a Light that's
      # ready to use. The Light is injected with a reference to this factory, allowing the
      # +Stoplight::Light#with+ method to work for reconfiguration.
      #
      # @return [Stoplight::Light] Configured circuit breaker
      # @raise [Stoplight::Error::ConfigurationError] If configuration is invalid
      #
      # @example
      #   factory = Stoplight::Wiring::LightFactory.new(container)
      #   light = factory.build
      #
      #   # Light is ready to use
      #   light.run { api_call }

      def build
        validate!

        Stoplight::Light.new(
          container.resolve(:config),
          data_store: container.resolve(:data_store),
          green_run_strategy: container.resolve(:green_run_strategy),
          yellow_run_strategy: container.resolve(:yellow_run_strategy),
          red_run_strategy: container.resolve(:red_run_strategy),
          factory: self
        )
      end

      def ==(other)
        other.is_a?(self.class) && other.container == container
      end

      private def extract_config_settings(settings)
        settings.slice(*container.resolve(:config).members)
      end

      private def extract_dependency_settings(settings)
        settings.slice(*container.keys)
      end

      private def validate_settings!(settings, config_settings, dependency_settings)
        recognized_keys = config_settings.keys + dependency_settings.keys
        unexpected_keys = settings.keys - recognized_keys

        return if unexpected_keys.empty?
        raise ArgumentError, "Unknown settings: #{unexpected_keys.join(", ")}"
      end

      private def transform_settings(settings)
        settings.dup.tap do |transformed_settings|
          transform_config_settings!(transformed_settings)
          transform_dependencies_settings!(transformed_settings)
        end
      end

      private def transform_config_settings!(settings)
        if settings.key?(:tracked_errors)
          settings[:tracked_errors] = normalize_array(settings[:tracked_errors])
        end

        if settings.key?(:skipped_errors)
          settings[:skipped_errors] = normalize_array(settings[:skipped_errors])
        end

        if settings.key?(:cool_off_time)
          settings[:cool_off_time] = normalize_cool_off_time(settings[:cool_off_time])
        end
      end

      private def transform_dependencies_settings!(settings)
        if settings.key?(:traffic_control)
          settings[:traffic_control] = apply_traffic_control_dsl(settings[:traffic_control])
        end

        if settings.key?(:traffic_recovery)
          settings[:traffic_recovery] = apply_traffic_recovery_dsl(settings[:traffic_recovery])
        end
      end

      private def normalize_array(value) = Array(value)
      private def normalize_cool_off_time(value) = value.to_i

      private def apply_traffic_control_dsl(traffic_control)
        case traffic_control
        in Domain::TrafficControl::Base
          traffic_control
        in :consecutive_errors
          Domain::TrafficControl::ConsecutiveErrors.new
        in :error_rate
          Domain::TrafficControl::ErrorRate.new
        in {error_rate: error_rate_settings}
          Domain::TrafficControl::ErrorRate.new(**error_rate_settings)
        else
          raise Domain::Error::ConfigurationError, <<~ERROR
            unsupported traffic_control strategy provided (`#{traffic_control}`). Supported options:
              * :consecutive_errors
              * :error_rate
          ERROR
        end
      end

      def apply_traffic_recovery_dsl(traffic_recovery)
        case traffic_recovery
        in Domain::TrafficRecovery::Base
          traffic_recovery
        in :consecutive_successes
          Domain::TrafficRecovery::ConsecutiveSuccesses.new
        else
          raise Domain::Error::ConfigurationError, <<~ERROR
            unsupported traffic_recovery strategy provided (`#{traffic_recovery}`). Supported options:
              * :consecutive_successes
          ERROR
        end
      end

      private def validate!
        validate_traffic_control!(container.resolve(:traffic_control), container.resolve(:config))
        validate_traffic_recovery!(container.resolve(:traffic_recovery), container.resolve(:config))
      end

      private def validate_traffic_control!(traffic_control, config)
        traffic_control.check_compatibility(config).then do |compatibility_result|
          if compatibility_result.incompatible?
            raise Domain::Error::ConfigurationError.new(
              "#{traffic_control.class.name} strategy is incompatible with the Stoplight configuration: #{compatibility_result.error_messages}"
            )
          end
        end
      end

      private def validate_traffic_recovery!(traffic_recovery, config)
        traffic_recovery.check_compatibility(config).then do |compatibility_result|
          if compatibility_result.incompatible?
            raise Domain::Error::ConfigurationError.new(
              "#{traffic_recovery.class.name} strategy is incompatible with the Stoplight configuration: #{compatibility_result.error_messages}"
            )
          end
        end
      end
    end
  end
end
