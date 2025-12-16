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
      private attr_reader :light_factory
      private attr_reader :lights

      # @api private
      def initialize(name, **defaults)
        @name = name.to_s
        @light_factory = LightFactory.new(library_default_dependencies.merge(defaults))
        @lights = Concurrent::Map.new

        light_factory.validate_configuration!
      end

      # Creates or retrieves a light.
      #
      # If a light with this name already exists, returns the cached instance.
      # If settings differ from the existing light, raises +Stoplight::Error::ConfigurationError+.
      #
      # @param name [String, Symbol] unique light name within this system
      # @param settings [Hash] light-specific configuration (overrides system defaults)
      # @option settings [Integer] :threshold failure threshold
      # @option settings [Integer] :recovery_threshold success threshold
      # @option settings [Numeric] :window_size time window in seconds
      # @option settings [Numeric] :cool_off_time cooldown period
      # @option settings [Symbol, Hash] :traffic_control failure detection strategy
      # @option settings [Symbol] :traffic_recovery recovery strategy
      # @option settings [Array<Class>] :tracked_errors errors to track
      # @option settings [Array<Class>] :skipped_errors errors to skip
      #
      # @return [Stoplight::Domain::Light]
      #
      # @raise [Stoplight::Error::ConfigurationError] if light exists with different settings
      # @raise [ArgumentError] if settings includes disallowed keys (e.g., :data_store)
      #
      # @example Create a light
      #   light = system.light("stripe", threshold: 5, window_size: 60)
      #
      # @example Retrieve existing light - both return cached light
      #   light = system.light("stripe", threshold: 5, window_size: 60)
      #   light = system.light("stripe")
      #
      # @example Configuration conflict
      #   system.light("api", threshold: 5)
      #   system.light("api", threshold: 10)  # Raises ConfigurationError
      #
      # @note Thread-safe: multiple threads can safely call this method concurrently
      #
      def light(name, **settings)
        light, _ = lights.compute(name) do |(existing_light, existing_normalized_settings)|
          normalized_settings = normalize_settings(settings)

          if existing_light
            if normalized_settings.empty? || normalized_settings == existing_normalized_settings
              [existing_light, existing_normalized_settings]
            else
              raise Stoplight::Error::ConfigurationError
            end
          else
            [light_factory.build_with(name:, **settings), normalized_settings]
          end
        end
        light
      end

      # @param settings [Hash]
      private def normalize_settings(settings) = settings.sort.to_h

      private def library_default_dependencies = {
        system: self,
        data_store: Default::DATA_STORE,
        traffic_recovery: Default::TRAFFIC_RECOVERY,
        traffic_control: Default::TRAFFIC_CONTROL,
        notifiers: Default::NOTIFIERS,
        error_notifier: Default::ERROR_NOTIFIER
      }.freeze
    end
  end
end
