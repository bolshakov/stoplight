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
    #
    class LightFactory < Domain::LightFactory
      # @!attribute [r] settings
      #   @return [Hash]
      protected attr_reader :settings

      def initialize(settings:)
        @settings = settings
      end

      # @return [Stoplight::Wiring::LightFactory]
      # @see Stoplight()
      def with(
        name: T.undefined,
        cool_off_time: T.undefined,
        threshold: T.undefined,
        recovery_threshold: T.undefined,
        window_size: T.undefined,
        tracked_errors: T.undefined,
        skipped_errors: T.undefined,
        data_store: T.undefined,
        error_notifier: T.undefined,
        notifiers: T.undefined,
        traffic_control: T.undefined,
        traffic_recovery: T.undefined
      )
        self.class.new(
          settings: settings.extend_with(
            name:,
            cool_off_time:,
            threshold:,
            recovery_threshold:,
            window_size:,
            tracked_errors:,
            skipped_errors:,
            data_store:,
            error_notifier:,
            notifiers:,
            traffic_control:,
            traffic_recovery:
          )
        )
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
        config = ConfigurationPipeline.process(settings:)
        light_builder(config:).build
      end

      def validate_configuration!
        ConfigurationPipeline.process(settings: settings.extend_with(name: "validate"))
      end

      def ==(other)
        other.is_a?(self.class) && other.settings == settings
      end

      alias_method :eql?, :==

      def hash
        [self.class, settings].hash
      end

      private def light_builder(config:)
        LightBuilder.new(config:, factory: light_factory)
      end

      private def light_factory = self
    end
  end
end
