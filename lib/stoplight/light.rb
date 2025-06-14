# frozen_string_literal: true

module Stoplight
  #
  # @api private use +Stoplight()+ method instead
  class Light
    extend Forwardable
    include ConfigurationBuilderInterface

    # @!attribute [r] config
    #   @return [Stoplight::Light::Config]
    #   @api private
    attr_reader :config

    # @!attribute [r] name
    #   The name of the light.
    #   @return [String]
    def_delegator :config, :name

    # @param config [Stoplight::Light::Config]
    def initialize(config, green_run_strategy: nil, yellow_run_strategy: nil, red_run_strategy: nil)
      @config = config
      @green_run_strategy = green_run_strategy
      @yellow_run_strategy = yellow_run_strategy
      @red_run_strategy = red_run_strategy
    end

    # Returns the current state of the light:
    #  * +Stoplight::State::LOCKED_GREEN+ -- light is locked green and allows all traffic
    #  * +Stoplight::State::LOCKED_RED+ -- light is locked red and blocks all traffic
    #  * +Stoplight::State::UNLOCKED+ -- light is not locked and follow the configured rules
    #
    # @return [String]
    def state
      config
        .data_store
        .get_metadata(config)
        .locked_state
    end

    # Returns current color:
    #   * +Stoplight::Color::GREEN+ -- circuit breaker is closed
    #   * +Stoplight::Color::RED+ -- circuit breaker is open
    #   * +Stoplight::Color::YELLOW+ -- circuit breaker is half-open
    #
    # @example
    #   light = Stoplight('example')
    #   light.color #=> Color::GREEN
    #
    # @return [String] returns current light color
    def color
      config
        .data_store
        .get_metadata(config)
        .color
    end

    # Runs the given block of code with this circuit breaker
    #
    # @example
    #   light = Stoplight('example')
    #   light.run { 2/0 }
    #
    # @example Running with fallback
    #   light = Stoplight('example')
    #   light.run(->(error) { 0 }) { 1 / 0 } #=> 0
    #
    # @param fallback [Proc, nil] (nil) fallback code to run if the circuit breaker is open
    # @raise [Stoplight::Error::RedLight]
    # @return [any]
    # @raise [Error::RedLight]
    def run(fallback = nil, &code)
      raise ArgumentError, "nothing to run. Please, pass a block into `Light#run`" unless block_given?

      strategy = state_strategy_factory(color)
      strategy.execute(fallback, &code)
    end

    # Locks light in either +State::LOCKED_RED+ or +State::LOCKED_GREEN+
    #
    # @example
    #   light = Stoplight('example-locked')
    #   light.lock(Stoplight::Color::RED)
    #
    # @param color [String] should be either +Color::RED+ or +Color::GREEN+
    # @return [Stoplight::Light] returns locked light (circuit breaker)
    def lock(color)
      state = case color
      when Color::RED then State::LOCKED_RED
      when Color::GREEN then State::LOCKED_GREEN
      else raise Error::IncorrectColor
      end

      config.data_store.set_state(config, state)

      self
    end

    # Unlocks light and sets its state to State::UNLOCKED
    #
    # @example
    #   light = Stoplight('example-locked')
    #   light.lock(Stoplight::Color::RED)
    #   light.unlock
    #
    # @return [Stoplight::Light] returns unlocked light (circuit breaker)
    def unlock
      config.data_store.set_state(config, Stoplight::State::UNLOCKED)

      self
    end

    # Two lights considered equal if they have the same configuration.
    #
    # @param other [any]
    # @return [Boolean]
    def ==(other)
      other.is_a?(self.class) && config == other.config
    end

    # Reconfigures the light with updated settings and returns a new instance.
    #
    # This method allows you to modify the configuration of a +Stoplight::Light+ object
    # by providing a hash of settings. The original light remains unchanged, and a new
    # light instance with the updated configuration is returned.
    #
    # @param settings [Hash] A hash of configuration options to update.
    # @option settings [String] :name The name of the light.
    # @option settings [Numeric] :cool_off_time The cool-off time in seconds before the light attempts recovery.
    # @option settings [Numeric] :threshold The failure threshold to trigger the red state.
    # @option settings [Numeric] :window_size The time window in seconds for counting failures.
    # @option settings [Stoplight::DataStore::Base] :data_store The data store to use for persisting light state.
    # @option settings [Array<Stoplight::Notifier::Base>] :notifiers A list of notifiers to handle light events.
    # @option settings [Proc] :error_notifier A custom error notifier to handle exceptions.
    # @option settings [Array<StandardError>] :tracked_errors A list of errors to track for failure counting.
    # @option settings [Array<StandardError>] :skipped_errors A list of errors to skip from failure counting.
    # @return [Stoplight::Light] A new `Stoplight::Light` instance with the updated configuration.
    #
    # @example Reconfiguring a light with custom settings
    #   light = Stoplight('payment-api')
    #
    #   # Create a light for invoices with a higher threshold
    #   invoices_light = light.with(tracked_errors: [TimeoutError], threshold: 10)
    #
    #   # Create a light for payments with a lower threshold
    #   payment_light = light.with(threshold: 5)
    #
    #   # Run the lights with their respective configurations
    #   invoices_light.run(->(error) { [] }) { call_invoices_api }
    #   payment_light.run(->(error) { nil }) { call_payment_api }
    # @see +Stoplight()+
    def with(**settings)
      reconfigure(
        Stoplight.config_provider.from_prototype(config, settings)
      )
    end

    private

    def state_strategy_factory(color)
      case color
      when Color::GREEN
        green_run_strategy
      when Color::YELLOW
        yellow_run_strategy
      else
        red_run_strategy
      end
    end

    # @return [Stoplight::Runnable::RunStrategy]
    def green_run_strategy
      @green_run_strategy ||= GreenRunStrategy.new(config)
    end

    # @return [Stoplight::Runnable::RunStrategy]
    def yellow_run_strategy
      @yellow_run_strategy ||= YellowRunStrategy.new(config)
    end

    # @return [Stoplight::Runnable::RunStrategy]
    def red_run_strategy
      @red_run_strategy ||= RedRunStrategy.new(config)
    end

    # @param config [Stoplight::Light::Config]
    # @return [Stoplight::Light]
    def reconfigure(config)
      self.class.new(config)
    end
  end
end
