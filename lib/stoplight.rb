# frozen_string_literal: true

require "configx"

require "stoplight/version"
require "stoplight/color"
require "stoplight/error"
require "stoplight/failure"
require "stoplight/state"

require "stoplight/data_store"
require "stoplight/data_store/base"
require "stoplight/data_store/memory"
require "stoplight/data_store/redis"

require "stoplight/notifier"
require "stoplight/notifier/base"
require "stoplight/notifier/generic"

require "stoplight/notifier/io"
require "stoplight/notifier/logger"

require "stoplight/default"

require "stoplight/types"
require "stoplight/circuit_breaker"
require "stoplight/light/base_config"
require "stoplight/light/config"
require "stoplight/config_provider"
require "stoplight/config"
require "stoplight/light/configurable"
require "stoplight/light/lockable"
require "stoplight/light/runnable"
require "stoplight/light"

module Stoplight # rubocop:disable Style/Documentation
  class << self
    attr_accessor :__programmatic_settings

    # Configures the +Stoplight+ with settings for all circuit breakers.
    #
    # This method allows configuring both:
    # - Config loading options (file paths, environment variable prefixes, etc.)
    # - Global default settings for all circuit breakers (data_store, threshold, etc.)
    #
    # Once configured, the configuration becomes immutable for the lifecycle of the application.
    # Call `reset_config!` if you need to reconfigure.
    #
    # @param settings [Hash] Configuration options
    #
    # @option settings [String] :config_root Path to the configuration directory (default: 'config')
    # @option settings [String] :dir_name Directory name for configuration files (default: 'stoplight')
    # @option settings [String] :file_name Base filename for configuration files (default: 'stoplight')
    # @option settings [String] :env_prefix Prefix for environment variables (default: 'STOPLIGHT')
    # @option settings [String] :env_separator Separator for environment variables (default: '__')
    #
    # You can also provide any circuit breaker setting as a global default:
    # @option settings [Numeric] :cool_off_time Default cool-off time for all circuit breakers
    # @option settings [Integer] :threshold Default error threshold for all circuit breakers
    # @option settings [Numeric] :window_size Default window size for all circuit breakers
    # @option settings [DataStore::Base] :data_store Default data store for all circuit breakers
    # @option settings [Array<Notifier::Base>] :notifiers Default notifiers for all circuit breakers
    # @option settings [Proc] :error_notifier Default error notifier for all circuit breakers
    #
    # @example Configure with defaults
    #   Stoplight.configure
    #
    # @example Configure with custom settings
    #   Stoplight.configure(
    #     config_root: 'custom_config',
    #     threshold: 5,
    #     data_store: Stoplight::DataStore::Redis.new(Redis.new)
    #   )
    #
    # @raise [RuntimeError] If Stoplight has already been configured
    # @return [void]
    def configure(**settings)
      raise "Stoplight is already configured" if @config

      configx_setting_names = %i[name env_prefix env_separator dir_name file_name config_root]
      configx_settings = settings.slice(*configx_setting_names)
      self.__programmatic_settings = settings.except(*configx_setting_names)

      @config = ConfigProvider.load(**configx_settings)
    end

    # @!attribute config
    # @return [Stoplight::Config]
    def config
      @config ||= configure
    end

    def reset_config!
      @config = nil
    end
  end
end

# Creates a new Stoplight circuit breaker with the given name and settings.
#
# @param name [String] The name of the circuit breaker.
# @param settings [Hash] Optional settings to configure the circuit breaker.
#   @option settings [Numeric] :cool_off_time The time to wait before resetting the circuit breaker.
#   @option settings [Stoplight::DataStore::Base] :data_store The data store to use for storing state.
#   @option settings [Proc] :error_notifier A proc to handle error notifications.
#   @option settings [Array<Stoplight::Notifier::Base>] :notifiers A list of notifiers to use.
#   @option settings [Numeric] :threshold The failure threshold to trip the circuit breaker.
#   @option settings [Numeric] :window_size The size of the rolling window for failure tracking.
#   @option settings [Array<StandardError>] :tracked_errors A list of errors to track.
#   @option settings [Array<Exception>] :skipped_errors A list of errors to skip.
#
# @return [Stoplight::CircuitBreaker] A new circuit breaker instance.
# @raise [ArgumentError] If an unknown option is provided in the settings.
def Stoplight(name, **settings) # rubocop:disable Naming/MethodName
  config = Stoplight.config.configure_light(name, **settings)
  Stoplight::Light.new(config)
end
