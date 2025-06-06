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

      # @param user_default_config [Stoplight::Config::UserDefaultConfig]
      # @param library_default_config [Stoplight::Config::LibraryDefaultConfig]
      # @raise [Error::ConfigurationError] if both user_default_config and legacy_config are not empty
      def initialize(user_default_config:, library_default_config:)
        @default_settings = library_default_config.to_h.merge(
          user_default_config.to_h
        )
      end

      # @return [Stoplight::DataStore::Base]
      def data_store
        default_settings.fetch(:data_store)
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

      def inspect
        "#<#{self.class.name} " \
          "cool_off_time=#{default_settings[:cool_off_time]}, " \
          "threshold=#{default_settings[:threshold]}, " \
          "window_size=#{default_settings[:window_size]}, " \
          "tracked_errors=#{default_settings[:tracked_errors].join(",")}, " \
          "skipped_errors=#{default_settings[:skipped_errors].join(",")}, " \
          "data_store=#{default_settings[:data_store].class.name}" \
        ">"
      end
    end
  end
end
