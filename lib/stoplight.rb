# frozen_string_literal: true

require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect("io" => "IO")
loader.do_not_eager_load(
  "#{__dir__}/stoplight/data_store",
  "#{__dir__}/stoplight/admin",
  "#{__dir__}/stoplight/admin.rb"
)
loader.ignore("#{__dir__}/stoplight/rspec.rb", "#{__dir__}/stoplight/rspec")
loader.setup

module Stoplight # rubocop:disable Style/Documentation
  CONFIG_MUTEX = Mutex.new
  private_constant :CONFIG_MUTEX

  class << self
    ALREADY_CONFIGURED_ERROR = "Stoplight must be configured only once"
    private_constant :ALREADY_CONFIGURED_ERROR

    # Configures the Stoplight library.
    #
    # This method allows you to set up the library's configuration using a block.
    # It raises an error if called more than once.
    #
    # @yield [config] Provides a configuration object to the block.
    # @yieldparam config [Stoplight::Config::ProgrammaticConfig] The configuration object.
    # @raise [Stoplight::Error::ConfigurationError] If the library is already configured.
    #
    # @example
    #   Stoplight.configure do |config|
    #     config.window_size = 14
    #     config.data_store = Stoplight::DataStore::Redis.new(redis_client)
    #     config.notifiers = [Stoplight::Notifier::IO.new($stdout)]
    #     config.cool_off_time = 120
    #     config.threshold = 5
    #     config.tracked_errors = [StandardError]
    #     config.skipped_errors = [RuntimeError]
    #   end
    #
    def configure
      raise Error::ConfigurationError, ALREADY_CONFIGURED_ERROR if @config_provider

      user_defaults = Config::UserDefaultConfig.new
      yield(user_defaults) if block_given?

      @config_provider = Config::ConfigProvider.new(
        user_default_config: user_defaults.freeze,
        library_default_config: Config::LibraryDefaultConfig.new
      )
    end

    # Retrieves the current configuration provider.
    #
    # @return [Stoplight::Config::ConfigProvider]
    # @api private
    def config_provider
      CONFIG_MUTEX.synchronize do
        @config_provider ||= configure
      end
    end

    # Resets the library's configuration.
    #
    # This method clears the current configuration, allowing the library to be reconfigured.
    def reset_config!
      @config_provider = nil
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
# @return [Stoplight::Light] A new circuit breaker instance.
# @raise [ArgumentError] If an unknown option is provided in the settings.
def Stoplight(name, **settings) # rubocop:disable Naming/MethodName
  config = Stoplight.config_provider.provide(name, **settings)
  Stoplight::Light.new(config)
end
