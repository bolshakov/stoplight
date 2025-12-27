# frozen_string_literal: true

module Stoplight
  module Wiring
    class System
      class LightFactory < Wiring::LightFactory
        ALLOWED_LIGHT_SETTINGS = [
          :cool_off_time,
          :name,
          :recovery_threshold,
          :skipped_errors,
          :threshold,
          :tracked_errors,
          :traffic_control,
          :traffic_recovery,
          :window_size
        ].freeze
        private_constant :ALLOWED_LIGHT_SETTINGS

        attr_reader :system

        def initialize(settings)
          @system = settings.delete(:system)

          super
        end

        # @param settings [Hash] Settings to override in the new factory
        #   @see Stoplight()
        # @return [Stoplight::Wiring::LightFactory]
        # @see Stoplight()
        def with(**settings)
          self.class.new(self.settings.merge(system:, **settings))
        end

        def build_with(**settings)
          unknown_settings = settings.keys - ALLOWED_LIGHT_SETTINGS
          raise ArgumentError, "Unknown settings: #{unknown_settings}", caller(7) unless unknown_settings.empty?

          super
        end

        class InternalLightFactory < Wiring::LightFactory
          def with(**settings) = raise NotImplementedError, "You're not allowed to extend system lights"
        end

        private def light_builder(config, dependencies)
          System::LightBuilder.new(system, {factory: light_factory, config:, **dependencies})
        end

        private def light_factory = InternalLightFactory.new(settings)
      end
    end
  end
end
