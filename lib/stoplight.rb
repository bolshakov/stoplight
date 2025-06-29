# frozen_string_literal: true

require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect("io" => "IO", "dsl" => "DSL")
loader.do_not_eager_load(
  "#{__dir__}/stoplight/data_store",
  "#{__dir__}/stoplight/admin",
  "#{__dir__}/stoplight/admin.rb"
)
loader.ignore("#{__dir__}/generators")
loader.ignore("#{__dir__}/stoplight/rspec.rb", "#{__dir__}/stoplight/rspec")
loader.setup

module Stoplight # rubocop:disable Style/Documentation
  CONFIG_DSL = Config::DSL.new
  private_constant :CONFIG_DSL

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
    # @yieldparam config [Stoplight::Config::UserDefaultConfig] The configuration object.
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
    #       configuration: ...f
    #
    #   If you really know what you are doing, you can pass the +trust_me_im_an_engineer+ parameter as +true+ to
    #   suppress this warning, which could be useful in test environments.
    #
    def configure(trust_me_im_an_engineer: false)
      user_defaults = Config::UserDefaultConfig.new
      yield(user_defaults) if block_given?

      reconfigured = !@default_config.nil?

      @default_config = Config::LibraryDefaultConfig.with(**user_defaults.to_h).tap do
        if reconfigured && !trust_me_im_an_engineer
          warn(
            "Stoplight reconfigured. Existing circuit breakers will not see new configuration. " \
              "New configuration: #{@default_config.inspect}"
          )
        end
      end
    end

    # Creates a Light for internal use.
    #
    # @param name [String]
    # @param settings [Hash]
    # @return [Stoplight::Light]
    # @api private
    def system_light(name, **settings)
      config = Config::SystemConfig.with(name:, **settings)
      Stoplight::Light.new(config)
    end

    # Create a Light with the user default configuration.
    #
    # @param name [String]
    # @param settings [Hash]
    # @return [Stoplight::Light]
    # @api private
    def light(name, **settings)
      config = Stoplight.default_config.with(name:, **settings)
      Stoplight::Light.new(config)
    end

    # Retrieves the current configuration provider.
    #
    # @return [Stoplight::Light::Config]
    # @api private
    def default_config
      CONFIG_MUTEX.synchronize do
        @default_config ||= configure
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
#   @option settings [Stoplight::TrafficControl::Base, Symbol, {Symbol, Hash{Symbol, any}}] :traffic_control The
#     traffic control strategy to use.
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
# @example configure traffic control to trip using consecutive failures method
#   # When 5 consecutive failures occur, the circuit breaker will trip.
#   light = Stoplight("Payment API", traffic_control: :consecutive_errors, threshold: 5)
#
# @example configure traffic control to trip using error rate method
#   # When 66.6% error rate reached withing a sliding 5 minute window, the circuit breaker will trip.
#   light = Stoplight("Payment API", traffic_control: :error_rate, threshold: 0.666, window_size: 300)
#
def Stoplight(name, **settings) # rubocop:disable Naming/MethodName
  Stoplight.light(name, **settings)
end
