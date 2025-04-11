# frozen_string_literal: true

require "configx"

module Stoplight
  # This is a Stoplight configuration class.
  #
  # It allows you to configure the default settings for all lights in one place,
  # for instance by setting a default window size, error threshold or data store.
  #
  # @see Stoplight::Light
  # @api private
  class Config < ConfigX::Config
    schema schema.strict

    # @!attribute default [Hash]
    #   @return [Hash] A user defined default settings for all lights. If some
    #     settings are not defined, the library-level default settings will be used.
    attribute :default, Light::BaseConfig.schema.default { {} }

    # @!attribute lights [Hash{String => Hash}]
    #  @return [Hash] A hash of light names and their settings. This allows you to
    #    configure each light with its own settings in a single place
    attribute :lights, Types::Hash.map(
      Types::Coercible::Symbol,
      Light::BaseConfig.schema
    ).default { {} }

    # Returns a configuration for a specific light with the given name and settings overrides.
    #
    # This method combines settings from three sources in the following order of precedence (last one wins):
    # 1. **Settings Overrides**: Explicit settings passed as arguments to this method.
    # 2. **Light-Specific Settings**: Settings defined for the specific light in the +lights+ attribute.
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
        .merge(light_settings(name))
        .merge(settings_overrides)
        .merge(name:)

      Light::Config.new(**settings)
    end

    # Returns the user-level default settings for the lights.
    # This allows users to configure the default settings for all lights in one place,
    # for instance by setting a default window size, error threshold or data store.
    #
    # @return [Hash]
    private def user_level_default_settings
      default
    end

    # Returns the default configuration for a specific light
    #
    # @param name [Symbol]
    # @return [Hash]
    private def light_settings(name)
      lights.fetch(name.to_sym, {}).to_h
    end
  end
end
