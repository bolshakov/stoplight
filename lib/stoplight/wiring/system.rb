# frozen_string_literal: true

require "concurrent/map"

module Stoplight
  module Wiring
    # 🚧UNDER CONSTRUCTION 🚧
    # System provides namespace isolation and shared configuration for related circuits.
    #
    # Systems enforce configuration consistency within their scope - creating the same
    # circuit name with different settings raises +Stoplight::Error::ConfigurationError+.
    #
    # This prevents subtle bugs where circuits silently interfere with each other.
    #
    # @example Basic usage
    #   billing = Stoplight.system(:billing,
    #     data_store: billing_redis,
    #     threshold: 5,
    #     window_size: 300
    #   )
    #
    #   billing.light("stripe")
    #   billing.light("paypal")
    #
    # @example Multi-tenancy
    #   tenant_a = Stoplight.system(:tenant_a, data_store: tenant_a_redis)
    #   tenant_b = Stoplight.system(:tenant_b, data_store: tenant_b_redis)
    #
    #   # Same circuit name, completely isolated
    #   tenant_a.light("api")
    #   tenant_b.light("api")
    #
    # @example Configuration inheritance
    #   system = Stoplight.system(:payments, threshold: 3, cool_off_time: 600)
    #
    #   system.light("stripe")                # Inherits threshold: 3
    #   system.light("paypal", threshold: 5)  # Overrides threshold
    #
    # @note System configuration objects (data_store, notifiers) should be defined
    #   as constants and reused, not created inline. This ensures configuration
    #   matching works correctly across multiple system references.
    #
    # @note Light instances are cached within the system. Calling {#light} with
    #   the same name returns the cached instance.
    #
    # @api private
    class System
      attr_reader :name
      # @!attribute system_config
      #   @api private
      attr_reader :system_config

      def initialize(config:)
        @name = config.name
        @system_config = config
        @lights = Concurrent::Map.new
      end

      # Creates or retrieves a light.
      #
      # If a light with this name already exists, returns the cached instance.
      # If settings differ from the existing light, raises +Stoplight::Error::ConfigurationError+.
      #
      # @raise [Stoplight::Error::ConfigurationError] if light exists with different settings
      #
      # @example Create a light
      #   light = system.light("stripe", threshold: 5, window_size: 60)
      #
      # @example Configuration conflict
      #   system.light("api", threshold: 5)
      #   system.light("api", threshold: 10)  # Raises ConfigurationError
      #
      # @note Thread-safe: multiple threads can safely call this method concurrently
      #
      def light(
        name,
        cool_off_time: T.undefined,
        threshold: T.undefined,
        recovery_threshold: T.undefined,
        window_size: T.undefined,
        tracked_errors: T.undefined,
        skipped_errors: T.undefined,
        traffic_control: T.undefined,
        traffic_recovery: T.undefined
      )
        light_config = ConfigurationDsl.new(
          name:,
          cool_off_time:,
          threshold:,
          recovery_threshold:,
          window_size:,
          tracked_errors:,
          skipped_errors:,
          traffic_control:,
          traffic_recovery:
        ).configure!(system_config)

        light, _ = lights.compute(name) do |existing|
          if existing
            existing_light, existing_config = existing
            if light_config == existing_config
              [existing_light, existing_config]
            else
              raise Stoplight::Error::ConfigurationError, <<~MSG
                Light name `#{name}` reused with different settings:
                  existing settings: #{existing_config}
                  new settings:      #{light_config}

                You cannot use the same light name with different settings.
              MSG
            end
          else
            [LightFactory.new(system: self, config: light_config).build, light_config]
          end
        end
        light
      end

      private

      attr_reader :lights
    end
  end
end
