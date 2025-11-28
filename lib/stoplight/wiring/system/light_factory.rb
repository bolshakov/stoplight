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

        def build_with(**settings)
          unknown_settings = settings.keys - ALLOWED_LIGHT_SETTINGS
          raise ArgumentError, "Unknown settings: #{unknown_settings}", caller(7) unless unknown_settings.empty?

          super
        end

        class InternalLightFactory < Wiring::LightFactory
          def with(**settings) = raise NotImplementedError, "You're not allowed to extend system lights"
        end

        private def light_factory = InternalLightFactory.new(settings)
      end
    end
  end
end
