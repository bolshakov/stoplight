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
      DEPENDENCY_KEYS = %i[data_store traffic_recovery traffic_control notifiers error_notifier].freeze
      private_constant :DEPENDENCY_KEYS

      CONFIG_KEYS = Domain::Config.members.freeze
      private_constant :CONFIG_KEYS

      # @!attribute [r] settings
      #   @return [Hash]
      protected attr_reader :settings

      def initialize(settings = {})
        @settings = settings

        validate_settings!
      end

      private def validate_settings!
        recognized = CONFIG_KEYS + DEPENDENCY_KEYS
        unknown = settings.keys - recognized

        return if unknown.empty?

        raise ArgumentError, "Unknown settings: #{unknown.join(", ")}", caller(2)
      end

      # @param settings [Hash] Settings to override in the new factory
      #   @see Stoplight()
      # @return [Stoplight::Wiring::LightFactory]
      # @see Stoplight()
      def with(**settings)
        self.class.new(self.settings.merge(settings))
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
        config_settings = settings.slice(*CONFIG_KEYS)
        dependency_settings = settings.slice(*DEPENDENCY_KEYS)

        config, dependencies = ConfigurationPipeline.process(
          config_settings,
          dependency_settings
        )
        light_builder(config, dependencies).build
      end

      # @return [Stoplight::Error::ConfigurationError]
      def validate_configuration!
        config_settings = settings.slice(*CONFIG_KEYS)
        dependency_settings = settings.slice(*DEPENDENCY_KEYS)

        ConfigurationPipeline.process(
          config_settings,
          dependency_settings
        )
        nil
      end

      def ==(other)
        other.is_a?(self.class) && other.settings == settings
      end

      alias_method :eql?, :==

      def hash
        [self.class, settings].hash
      end

      private def light_builder(config, dependencies)
        LightBuilder.new({factory: light_factory, config:, **dependencies})
      end

      private def light_factory = self
    end
  end
end
