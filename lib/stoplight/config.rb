# frozen_string_literal: true

module Stoplight
  # This is a Stoplight configuration class.
  #
  # It allows you to configure the default settings for all lights in one place,
  # for instance by setting a default window size, error threshold or data store.
  #
  # @see Stoplight::Light
  # @api private
  class Config < Dry::Struct
    schema schema.strict
    transform_keys(&:to_sym)

    # @!attribute default [Hash]
    #   @return [Hash] A user defined default settings for all lights. If some
    #     settings are not defined, the library-level default settings will be used.
    attribute :default, Light::BaseConfig.schema.default { {} }

    # Returns a configuration for a specific light with the given name and settings overrides.
    #
    # This method combines settings from three sources in the following order of precedence (last one wins):
    # 1. **Settings Overrides**: Explicit settings passed as arguments to this method.
    # 3. **User-Level Default Settings**: General default settings defined in the +default+ attribute.
    # 4. **Library-Level Default Settings**: Default settings defined in the +Stoplight::Light::Config::DEFAULT_SETTINGS+ module.
    #
    # The settings are merged in this order, with higher-precedence settings overriding lower-precedence ones.
    #
    # @param name [Symbol, String] The name of the light.
    # @param settings_overrides [Hash] The settings to override.
    # @return [Stoplight::Light::Config] The configuration for the specified light.
    def configure_light(name, **settings_overrides)
      settings = user_level_default_settings
        .merge(settings_overrides)
        .merge(name:)

      Light::Config.new(**settings)
    end

    # @return [Hash]
    private def user_level_default_settings
      default
    end
  end
end
