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
    # After merging settings, the configuration transformations are applied such as wrapping data stores and notifiers
    # with fail-safe mechanism, type conversion, etc. Each transformation must be idempotent.
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
      def provide(light_name, settings_overrides = {})
        raise Error::ConfigurationError, <<~ERROR if settings_overrides.has_key?(:name)
          The +name+ setting cannot be overridden in the configuration.
        ERROR

        settings = default_settings.merge(settings_overrides, {name: light_name})
        validate_config!(
          Light::Config.new(**transform_settings(settings))
        )
      end

      # Creates a configuration from a given +Stoplight::Light::Config+ object extending it
      # with additional settings overrides.
      #
      # @param config [Stoplight::Light::Config] The configuration object to extend.
      # @param settings_overrides [Hash] The settings to override.
      # @return [Stoplight::Light::Config] The new extended configuration object.
      def from_prototype(config, settings_overrides)
        config.to_h.then do |settings|
          current_name = settings.delete(:name)
          name = settings_overrides.delete(:name) || current_name

          provide(name, **settings.merge(settings_overrides))
        end
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

      private

      def transform_settings(settings)
        settings.merge(
          data_store: build_data_store(settings.fetch(:data_store)),
          notifiers: build_notifiers(settings.fetch(:notifiers)),
          tracked_errors: build_tracked_errors(settings.fetch(:tracked_errors)),
          skipped_errors: build_skipped_errors(settings.fetch(:skipped_errors)),
          cool_off_time: build_cool_off_time(settings.fetch(:cool_off_time)),
          traffic_control: build_traffic_control(settings.fetch(:traffic_control))
        )
      end

      def build_data_store(data_store)
        DataStore::FailSafe.wrap(data_store)
      end

      def build_notifiers(notifiers)
        notifiers.map { |notifier| Notifier::FailSafe.wrap(notifier) }
      end

      def build_tracked_errors(tracked_error)
        Array(tracked_error)
      end

      def build_skipped_errors(skipped_errors)
        Array(skipped_errors)
      end

      def build_cool_off_time(cool_off_time)
        cool_off_time.to_i
      end

      def build_traffic_control(traffic_control)
        case traffic_control
        in Stoplight::TrafficControl::Base
          traffic_control
        in :consecutive_errors
          Stoplight::TrafficControl::ConsecutiveErrors.new
        in :error_rate
          Stoplight::TrafficControl::ErrorRate.new
        in {error_rate: error_rate_settings}
          Stoplight::TrafficControl::ErrorRate.new(**error_rate_settings)
        else
          raise Error::ConfigurationError, <<~ERROR
            unsupported traffic_control strategy provided (`#{traffic_control}`). Supported options:
              * Stoplight::TrafficControl::ConsecutiveErrors
              * Stoplight::TrafficControl::ErrorRate
          ERROR
        end
      end

      def validate_config!(config)
        validate_traffic_control_compatibility!(config)
        config
      end

      def validate_traffic_control_compatibility!(config)
        config.traffic_control.check_compatibility(config).then do |compatibility_result|
          if compatibility_result.incompatible?
            raise Stoplight::Error::ConfigurationError.new(
              "#{config.traffic_control.class.name} strategy is incompatible with the Stoplight configuration: #{compatibility_result.error_messages}"
            )
          end
        end
      end
    end
  end
end
