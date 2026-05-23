# frozen_string_literal: true

require "concurrent/map"
require "zeitwerk"

# steep:ignore:start
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
# steep:ignore:end

module Stoplight # rubocop:disable Style/Documentation
  T = Types

  CONFIG_MUTEX = Mutex.new
  private_constant :CONFIG_MUTEX
  @systems = Concurrent::Map.new

  class << self
    # Configures the Stoplight library.
    #
    # This method allows you to set up the library's configuration using a block.
    # It raises an error if called more than once.
    # @param trust_me_im_an_engineer [Boolean]
    # @yield [config] Provides a configuration object to the block.
    # @yieldparam config [Stoplight::Wiring::DefaultConfiguration] The configuration object.
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
      warn_if_reconfiguring(trust_me_im_an_engineer) do
        configuration = Wiring::DefaultConfiguration.new
        yield configuration if block_given?

        default_config = configuration.to_config!
        @default_config = default_config
        @default_light_factory = Wiring::LightFactory.new(config: default_config)
      end
    end

    # @api private
    def system_light(
      name,
      cool_off_time: T.undefined,
      threshold: T.undefined,
      recovery_threshold: T.undefined,
      window_size: T.undefined,
      tracked_errors: T.undefined,
      skipped_errors: T.undefined,
      data_store: T.undefined,
      error_notifier: T.undefined,
      notifiers: T.undefined,
      traffic_control: T.undefined,
      traffic_recovery: T.undefined
    )
      Wiring::LightFactory.new(config: Wiring::DefaultConfig).build_with(
        name: "__stoplight__#{name}",
        cool_off_time:,
        threshold:,
        recovery_threshold:,
        window_size:,
        tracked_errors:,
        skipped_errors:,
        data_store:,
        error_notifier:,
        notifiers:,
        traffic_control:,
        traffic_recovery:
      )
    end

    # Create a Light with the user default configuration.
    #
    # @return [Stoplight::Light]
    # @api private
    def light(
      name,
      cool_off_time: T.undefined,
      threshold: T.undefined,
      recovery_threshold: T.undefined,
      window_size: T.undefined,
      tracked_errors: T.undefined,
      skipped_errors: T.undefined,
      data_store: T.undefined,
      error_notifier: T.undefined,
      notifiers: T.undefined,
      traffic_control: T.undefined,
      traffic_recovery: T.undefined
    )
      __stoplight__default_light_factory.build_with(
        name:,
        cool_off_time:,
        threshold:,
        recovery_threshold:,
        window_size:,
        tracked_errors:,
        skipped_errors:,
        data_store:,
        error_notifier:,
        notifiers:,
        traffic_control:,
        traffic_recovery:
      )
    end

    # Creates a new named system with the given configuration.
    #
    # Systems are composition roots that own infrastructure (data store, notifiers)
    # and enforce configuration consistency for all lights created within them.
    #
    # @param name [String] Unique identifier for the system
    # @param settings [Hash] Configuration options that override global defaults.
    #   @see Stoplight() documentation
    #
    # @return [Stoplight::Wiring::System] A new system instance.
    #
    # @raise [ArgumentError] If a system with the given name already exists.
    #
    # @note Systems are not cached for reuse. Assign the returned system to a constant
    #   for repeated access. Calling this method twice with the same name raises an error.
    #
    # @example Creating a system for payment services
    #   Payments = Stoplight.__stoplight__system(:payments, threshold: 3, cool_off_time: 30)
    #   Payments.light("stripe").run { process_payment }
    #
    # @example Isolated system with dedicated data store
    #   Analytics = Stoplight.__stoplight__system(:analytics, data_store: analytics_redis)
    #
    # @api private
    def __stoplight__system(
      name,
      cool_off_time: T.undefined,
      threshold: T.undefined,
      recovery_threshold: T.undefined,
      window_size: T.undefined,
      tracked_errors: T.undefined,
      skipped_errors: T.undefined,
      data_store: T.undefined,
      error_notifier: T.undefined,
      notifiers: T.undefined,
      traffic_control: T.undefined,
      traffic_recovery: T.undefined
    )
      ensure_configured

      systems.compute(name.to_s) do |existing_system|
        if existing_system
          raise ArgumentError, "system `#{name}` is already in use"
        else
          Wiring::System.new(
            config: Wiring::SystemConfigurationDsl.new(
              name: name.to_s,
              cool_off_time:,
              threshold:,
              recovery_threshold:,
              window_size:,
              tracked_errors:,
              skipped_errors:,
              traffic_control:,
              traffic_recovery:,
              data_store:,
              error_notifier:,
              notifiers:
            ).configure!(default_config)
          )
        end
      end
    end

    private attr_reader :systems
    private def default_config = T.must(@default_config)

    # Resets Stoplight to an unconfigured state.
    #
    # Clears all registered systems, default configuration, and the default light factory.
    # After calling this method, the next call to +Stoplight()+ or +configure+ will
    # initialize fresh state.
    #
    # @return [void]
    #
    # @note This method is intended for test suite setup/teardown. Do not use in production
    #   code, as it orphans any existing light or system references, leading to split-brain
    #   scenarios where different lights with the same name use different data stores.
    #
    # @note This method does not clean up state in external data stores (e.g., Redis keys).
    #   It only resets in-process configuration.
    #
    # @example RSpec test setup
    #   RSpec.configure do |config|
    #     config.before do
    #       Stoplight.__stoplight__reset!
    #     end
    #   end
    #
    # @api private
    def __stoplight__reset!
      @systems = Concurrent::Map.new
      @default_config = nil
      @default_light_factory = nil
      @configured = nil
    end

    # Retrieves the current default dependencies.
    #
    # @return [Stoplight::Domain::LightFactory]
    # @api private
    def __stoplight__default_light_factory
      ensure_configured
      T.must(@default_light_factory)
    end

    def __stoplight__default_configuration
      ensure_configured
      T.must(@default_config)
    end

    # @api private
    private def ensure_configured
      CONFIG_MUTEX.synchronize do
        configure unless configured?
      end
    end

    private def warn_if_reconfiguring(trust_me_im_an_engineer)
      if configured? && !trust_me_im_an_engineer
        warn "Stoplight reconfigured. Existing circuit breakers will not see new configuration"
      end
      yield
      @configured = true
    end

    private def configured?
      @configured == true
    end
  end
end

# Creates a new Stoplight circuit brNeaker with the given name and settings.
#
# @param name [String] The name of the circuit breaker.
# @param settings [Hash] Optional settings to configure the circuit breaker.
#   @option settings [Numeric] :cool_off_time The time to wait before resetting the circuit breaker.
#   @option settings [Stoplight::DataStore::Base] :data_store The data store to use for storing state.
#   @option settings [Array<Stoplight::Notifier::Base>] :notifiers A list of notifiers to use.
#   @option settings [Numeric] :threshold The failure threshold to trip the circuit breaker.
#   @option settings [Numeric] :window_size The size of the rolling window for failure tracking.
#   @option settings [Array<StandardError>] :tracked_errors A list of errors to track.
#   @option settings [Array<Exception>] :skipped_errors A list of errors to skip.
#   @option settings [Symbol, {Symbol, Hash{Symbol, any}}] :traffic_control The
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
def Stoplight(
  name,
  cool_off_time: Stoplight::T.undefined,
  threshold: Stoplight::T.undefined,
  recovery_threshold: Stoplight::T.undefined,
  window_size: Stoplight::T.undefined,
  tracked_errors: Stoplight::T.undefined,
  skipped_errors: Stoplight::T.undefined,
  data_store: Stoplight::T.undefined,
  error_notifier: Stoplight::T.undefined,
  notifiers: Stoplight::T.undefined,
  traffic_control: Stoplight::T.undefined,
  traffic_recovery: Stoplight::T.undefined
) # rubocop:disable Naming/MethodName
  Stoplight::Common::Deprecations.deprecate(<<~MSG) if error_notifier != Stoplight::T.undefined
    Passing "error_notifier" to Stoplight('#{name}') is deprecated and will be removed in v6.0.0.

    IMPORTANT: The `error_notifier` is NOT called for exceptions in your protected code.
    It only reports internal Stoplight failures (e.g., Redis connection errors).

    To fix: Move `error_notifier` to global configuration:

      Stoplight.configure do |config|
        config.error_notifier = ->(error) { Logger.warn(error) }
      end

    See: https://github.com/bolshakov/stoplight#error-notifiers
  MSG
  Stoplight.light(
    name,
    cool_off_time:,
    threshold:,
    recovery_threshold:,
    window_size:,
    tracked_errors:,
    skipped_errors:,
    data_store:,
    error_notifier:,
    notifiers:,
    traffic_control:,
    traffic_recovery:
  )
end
