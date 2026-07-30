# frozen_string_literal: true

require "concurrent/map"

module Stoplight
  module Wiring
    # System provides namespace isolation and shared configuration for related circuits.
    #
    # Systems enforce configuration consistency within their scope - creating the same
    # circuit name with different settings raises +Stoplight::Error::ConfigurationError+.
    #
    # This prevents subtle bugs where circuits silently interfere with each other.
    #
    # @example Basic usage
    #   billing = Stoplight.__stoplight__system(:billing,
    #     data_store: billing_redis,
    #     threshold: 5,
    #     window_size: 300
    #   )
    #
    #   billing.register("stripe")
    #   billing.register("paypal")
    #
    #   billing.light("stripe").run { ... }
    #   billing.light("paypal").run { ... }
    #
    # @example Multi-tenancy
    #   tenant_a = Stoplight.__stoplight__system(:tenant_a, data_store: tenant_a_redis)
    #   tenant_b = Stoplight.__stoplight__system(:tenant_b, data_store: tenant_b_redis)
    #
    #   # Same circuit name, completely isolated
    #   tenant_a.register("api")
    #   tenant_b.register("api")
    #
    # @example Configuration inheritance
    #   system = Stoplight.__stoplight__system(:payments, threshold: 3, cool_off_time: 600)
    #
    #   system.register("stripe")                # Inherits threshold: 3
    #   system.register("paypal", threshold: 5)  # Overrides threshold
    #
    # @note Light instances are cached within the system once {#register}ed. {#light}
    #   returns that cached instance and raises +Stoplight::Error::UnregisteredLightError+
    #   if the name was never registered.
    class System
      attr_reader :name
      # @api private
      attr_reader :config

      # Returns the consumer (subscribe-only) side of the telemetry bus.
      def telemetry
        Domain::Telemetry::Consumer.new(@telemetry)
      end

      # @param failover_system is a system used to create lights that protects components
      #   of this system. For example if your system uses Redis data store, or notifiers that
      #   communicate with external systems, they could go off. Failover system hosts
      #   all the circuit breakers that are needed to protect these dependencies from failing.
      #   Failover system itself never uses external dependencies and therefore does not need
      #   external failover.
      def initialize(config:, failover_system:, registry:)
        @name = config.name
        @config = config
        @lights = Concurrent::Map.new
        @failover_system = failover_system
        @registry = registry
        @telemetry = Domain::Telemetry::Bus.new(error_notifier: config.error_notifier)
      end

      def persistent?
        case @config.data_store
        when DataStore::Redis
          true
        when DataStore::Memory
          false
        else
          raise T.absurd(@config.data_store)
        end
      end

      # Registers and returns a light.
      #
      # If a light with this name already exists, returns it.
      # If settings differ from the existing light, raises +Stoplight::Error::ConfigurationError+.
      #
      # @raise [Stoplight::Error::ConfigurationError] if light exists with different settings
      #
      # @example Register a light
      #   system.register("stripe", threshold: 5, window_size: 60)
      #   system.light("stripe") #=> returns named light
      #
      # @example Configuration conflict
      #   system.register("api", threshold: 5)
      #   system.register("api", threshold: 10)  # Raises ConfigurationError
      #
      # @note Thread-safe: multiple threads can safely call this method concurrently
      #
      def register(
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

        light, existing_digest, existing_source_line = @lights.compute_if_absent(name) do
          source_line = caller(6, 1)&.first # Very expensive call
          config = light_dsl.configure!(@config)
          built = LightFactory.new(
            system_name: @name, config:,
            failover_system: @failover_system,
            telemetry: @telemetry
          ).build
          @registry.register(name, config:)
          [built, config_digest, source_line]
        end

        if config_digest != existing_digest
          source_line = caller(1, 1)&.first # Very expensive call

          raise Stoplight::Error::ConfigurationError, <<~MSG
            Light `#{name}` already registered with different configuration.
            Original registration: #{existing_source_line}
            Current attempt: #{source_line}

            Lights must have consistent configuration across all call sites.
          MSG
        end

        light
      end

      # @raise [Stoplight::Error::UnregisteredLightError] if no light was registered under +name+
      def light(name)
        @lights[name]&.first || raise(Stoplight::Error::UnregisteredLightError, <<~MSG)
          Light `#{name}` was never registered on system `#{@name}`.
          Call `.register(#{name.inspect}, ...)` at boot before using it.
        MSG
      end

      # @api private
      def __stoplight__storage
        Storage.new(
          system_name: @name,
          failover_system: T.must(@failover_system), # works only with redis ds
          telemetry: @telemetry
        )
      end

      # @api private
      def __stoplight__registry
        @registry
      end
    end
  end
end
