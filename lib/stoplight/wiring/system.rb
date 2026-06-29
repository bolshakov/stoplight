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

      # @param failover_system is a system used to create lights that protects components
      #   of this system. For example if your system uses Redis data store, or notifiers that
      #   communicate with external systems, they could go off. Failover system hosts
      #   all the circuit breakers that are needed to protect these dependencies from failing.
      #   Failover system itself never uses external dependencies and thereforec does not need
      #   external failover.
      def initialize(config:, failover_system:, registry:)
        @name = config.name
        @system_config = config
        @lights = Concurrent::Map.new
        @failover_system = failover_system
        @registry = registry
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
        light_dsl = LightConfigurationDsl.new(
          name:,
          cool_off_time:,
          threshold:,
          recovery_threshold:,
          window_size:,
          tracked_errors:,
          skipped_errors:,
          traffic_control:,
          traffic_recovery:
        )
        config_digest = light_dsl.digest
        light, _, _ = lights.compute(name) do |existing|
          if existing
            _, existing_digest, existing_source_line = existing

            if config_digest != existing_digest
              raise Stoplight::Error::ConfigurationError, <<~MSG
                Light `#{name}` already registered with different configuration.

                Original registration: #{existing_source_line}
                Current attempt: #{caller(6, 1)&.first}

                Lights must have consistent configuration across all call sites.
              MSG
            end

            existing
          else
            source_line = caller(6, 1)&.first
            config = light_dsl.configure!(system_config)
            light = LightFactory.new(system_name: @name, config:, failover_system: @failover_system).build
            @registry.register(name, config:)
            [light, config_digest, source_line]
          end
        end

        light
      end

      # @api private
      def __stoplight__storage
        Storage.new(system_name: @name, failover_system: T.must(@failover_system)) # works only with redis ds
      end

      # @api private
      def __stoplight__registry
        @registry
      end

      private

      attr_reader :lights
    end
  end
end
