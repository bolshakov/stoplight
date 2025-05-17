# frozen_string_literal: true

module Stoplight
  module Config
    # Provides configuration for a Stoplight light by its name.
    #
    # It combines settings from three sources in the following order of precedence:
    # 1. **Settings Overrides**: Explicit settings passed as arguments to +#provide+ method.
    # 2. **User-level Default Settings**: Settings defined using the +Stoplight.configure+ method.
    # 4. **Library-Level Default Settings**: Default settings defined in the +Stoplight::Config::UserDefaultConfig+ module.
    #
    # The settings are merged in this order, with higher-precedence settings overriding lower-precedence ones.
    #
    # @api private
    class ConfigProvider
      # @!attribute [r] default_settings
      #   @return [Hash]
      private attr_reader :default_settings

      CONFIGURATION_ERROR = <<~ERROR
        Configuration conflict detected!
          
        You've attempted to use both the old and new configuration styles:
          - Old style: Stoplight.default_data_store = value
          - New style: Stoplight.configure { |config| config.data_store = value }
        
        Please choose only one configuration method for consistency.
        Note: The old style is deprecated and will be removed in a future version.
      ERROR
      private_constant :CONFIGURATION_ERROR

      # @param user_default_config [Stoplight::Config::UserDefaultConfig]
      # @param legacy_config [Stoplight::Config::LegacyConfig]
      # @param library_default_config [Stoplight::Config::LibraryDefaultConfig]
      # @raise [Error::ConfigurationError] if both user_default_config and legacy_config are not empty
      def initialize(user_default_config:, legacy_config:, library_default_config:)
        if user_default_config.any? && legacy_config.any?
          raise Error::ConfigurationError, CONFIGURATION_ERROR
        end

        @default_settings = library_default_config.to_h.merge(
          user_default_config.to_h,
          legacy_config.to_h
        )
      end

      # Returns a configuration for a specific light with the given name and settings overrides.
      #
      # @param light_name [Symbol, String] The name of the light.
      # @param settings_overrides [Hash] The settings to override.
      #   @see +Stoplight()+
      # @return [Stoplight::Light::Config] The configuration for the specified light.
      # @raise [Error::ConfigurationError]
      def provide(light_name, **settings_overrides)
        raise Error::ConfigurationError, <<~ERROR if settings_overrides.has_key?(:name)
          The +name+ setting cannot be overridden in the configuration.
        ERROR

        settings = default_settings.merge(settings_overrides, {name: light_name})
        Light::Config.new(**settings)
      end
    end
  end
end
