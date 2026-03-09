# frozen_string_literal: true

module Stoplight
  module Domain
    #
    # @api private use +Stoplight()+ method instead
    class Light
      include Common::Deprecations
      include ConfigurationBuilderInterface # steep:ignore

      attr_reader :name

      attr_reader :green_run_strategy
      attr_reader :yellow_run_strategy
      attr_reader :red_run_strategy
      attr_reader :factory
      attr_reader :state_store

      def initialize(name, green_run_strategy:, yellow_run_strategy:, red_run_strategy:, factory:, state_store:)
        @name = name
        @green_run_strategy = green_run_strategy
        @yellow_run_strategy = yellow_run_strategy
        @red_run_strategy = red_run_strategy
        @factory = factory
        @state_store = state_store
      end

      # Returns the current state of the light:
      #  * +Stoplight::State::LOCKED_GREEN+ -- light is locked green and allows all traffic
      #  * +Stoplight::State::LOCKED_RED+ -- light is locked red and blocks all traffic
      #  * +Stoplight::State::UNLOCKED+ -- light is not locked and follow the configured rules
      #
      def state = state_snapshot.locked_state

      # Returns current color:
      #   * +Stoplight::Color::GREEN+ -- circuit breaker is closed
      #   * +Stoplight::Color::RED+ -- circuit breaker is open
      #   * +Stoplight::Color::YELLOW+ -- circuit breaker is half-open
      #
      # @example
      #   light = Stoplight('example')
      #   light.color #=> Color::GREEN
      #
      def color = state_snapshot.color

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
      # @param fallback fallback code to run if the circuit breaker is open
      # @raise [Stoplight::Error::RedLight]
      def run(fallback = nil, &code)
        raise ArgumentError, "nothing to run. Please, pass a block into `Light#run`" unless block_given?

        state_snapshot.then do |state_snapshot|
          strategy = state_strategy_factory(state_snapshot.color)
          strategy.execute(fallback, state_snapshot:, &code)
        end
      end

      # Locks light in either +State::LOCKED_RED+ or +State::LOCKED_GREEN+
      #
      # @example
      #   light = Stoplight('example-locked')
      #   light.lock(Stoplight::Color::RED)
      #
      # @param color should be either +Color::RED+ or +Color::GREEN+
      # @return locked light
      def lock(color)
        state = case color
        when Color::RED then State::LOCKED_RED
        when Color::GREEN then State::LOCKED_GREEN
        else raise Error::IncorrectColor
        end

        state_store.set_state(state)

        self
      end

      # Unlocks light and sets its state to State::UNLOCKED
      #
      # @example
      #   light = Stoplight('example-locked')
      #   light.lock(Stoplight::Color::RED)
      #   light.unlock
      #
      # @return returns unlocked light (circuit breaker)
      def unlock
        state_store.set_state(State::UNLOCKED)

        self
      end

      # Two lights considered equal if they have the same configuration.
      def ==(other)
        other.is_a?(self.class) && factory == other.factory
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
      # @option settings [Array<Stoplight::Domain::AbstractStateTransitionNotifier>] :notifiers A list of notifiers to handle light events.
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
      # @deprecated
      # @see +Stoplight()+
      # steep:ignore:start
      def with(**settings)
        deprecate(<<~MSG)
          Light#with is deprecated and will be removed in v6.0.0.

          Circuit breakers should be configured once at creation, not cloned with
          modifications.

          Instead of:
            light = Stoplight('api-call', threshold: 5)
            modified = light.with(threshold: 10)

          Configure correctly from the start:
            Stoplight('api-call', threshold: 10)
        MSG
        with_without_warning(**settings)
      end

      private def with_without_warning(**settings)
        factory.build_with(**settings)
      end
      # steep:ignore:end

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

      def state_snapshot = state_store.state_snapshot
    end
  end
end
