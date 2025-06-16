# frozen_string_literal: true

require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect("io" => "IO")
loader.do_not_eager_load(
  "#{__dir__}/stoplight/data_store",
  "#{__dir__}/stoplight/admin",
  "#{__dir__}/stoplight/admin.rb"
)
loader.ignore("#{__dir__}/generators")
loader.ignore("#{__dir__}/stoplight/rspec.rb", "#{__dir__}/stoplight/rspec")
loader.setup

module Stoplight # rubocop:disable Style/Documentation
  CONFIG_MUTEX = Mutex.new
  private_constant :CONFIG_MUTEX

  class << self
    ALREADY_CONFIGURED_WARNING = "Stoplight must be configured only once"
    private_constant :ALREADY_CONFIGURED_WARNING

    # Configures the Stoplight library.
    #
    # This method allows you to set up the library's configuration using a block.
    # It raises an error if called more than once.
    #
    # @yield [config] Provides a configuration object to the block.
    # @yieldparam config [Stoplight::Config::ProgrammaticConfig] The configuration object.
    # @raise [Stoplight::Error::ConfigurationError] If the library is already configured.
    # @return [void]
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
    # @note It is not recommended to call this method multiple times because after reconfiguring Stoplight
    #   it will not be possible to change the configuration of existing circuit breakers. If you do so, the method
    #   produces a warning:
    #
    #     "Stoplight reconfigured. Existing circuit breakers will not see the new configuration. New
    #       configuration: #<Stoplight::Config::ConfigProvider cool_off_time=32, threshold=3, window_size=94, tracked_errors=StandardError, skipped_errors=NoMemoryError,ScriptError,SecurityError,SignalException,SystemExit,SystemStackError, data_store=Stoplight::DataStore::Memory>\n"
    #
    #   If you really know what you are doing, you can pass the +trust_me_im_an_engineer+ parameter as +true+ to
    #   suppress this warning, which could be useful in test environments.
    #
    def configure(trust_me_im_an_engineer: false)
      user_defaults = Config::UserDefaultConfig.new
      yield(user_defaults) if block_given?

      reconfigured = !@config_provider.nil?

      @config_provider = Config::ConfigProvider.new(
        user_default_config: user_defaults.freeze,
        library_default_config: Config::LibraryDefaultConfig.new
      ).tap do
        if reconfigured && !trust_me_im_an_engineer
          warn(
            "Stoplight reconfigured. Existing circuit breakers will not see new configuration. " \
              "New configuration: #{@config_provider.inspect}"
          )
        end
      end
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
#
# @example configure circuit breaker behavior
#   light = Stoplight("Payment API", window_size: 300, threshold: 5, cool_off_time: 60)
#
# @example configure data store
#   light = Stoplight("Payment API", data_store: Stoplight::DataStore::Redis.new(redis_client))
#
# In the example below, the +TimeoutError+ and +NetworkError+ exceptions
# will be counted towards the threshold for moving the circuit breaker into the red state.
# If not configured, the default tracked error is +StandardError+.
#
# @example configure tracked errors
#   light = Stoplight("Payment API", tracked_errors: [TimeoutError, NetworkError])
#
# In the example below , the +ActiveRecord::RecordNotFound+ doesn't
# move the circuit breaker into the red state.
#
# @example configure skipped errors
#   light = Stoplight("Payment API", skipped_errors: [ActiveRecord::RecordNotFound])
#
def Stoplight(name, **settings) # rubocop:disable Naming/MethodName
  config = Stoplight.config_provider.provide(name, **settings)
  Stoplight::Light.new(config)
end
