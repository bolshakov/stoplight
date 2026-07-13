# frozen_string_literal: true

module Stoplight
  module Domain
    #
    # @api private use +Stoplight()+ method instead
    class Light
      attr_reader :name
      attr_reader :green_run_strategy
      attr_reader :yellow_run_strategy
      attr_reader :red_run_strategy
      attr_reader :state_store

      def initialize(
        name,
        green_run_strategy:,
        yellow_run_strategy:,
        red_run_strategy:,
        state_store:,
        lock_control:,
        error_tracking_policy:
      )
        @name = name
        @green_run_strategy = green_run_strategy
        @yellow_run_strategy = yellow_run_strategy
        @red_run_strategy = red_run_strategy
        @state_store = state_store
        @lock_control = lock_control
        @error_tracking_policy = error_tracking_policy
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
      # @example Overriding tracked errors for one run
      #   light.run(tracked_errors: [Timeout::Error]) { fetch_data }
      #
      # @param fallback fallback code to run if the circuit breaker is open
      # @param tracked_errors errors to track for this run; replaces the configured list
      # @param skipped_errors errors to skip for this run; replaces the configured list
      # @raise [Stoplight::Error::RedLight]
      def run(fallback = nil, tracked_errors: T.undefined, skipped_errors: T.undefined, &code)
        raise ArgumentError, "nothing to run. Please, pass a block into `Light#run`" unless block_given?

        state_snapshot.then do |state_snapshot|
          strategy = state_strategy_factory(state_snapshot.color)
          error_tracking_policy = @error_tracking_policy.with(tracked: tracked_errors, skipped: skipped_errors)
          strategy.execute(fallback, state_snapshot:, error_tracking_policy:, &code)
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
        @lock_control.lock(color)

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
        @lock_control.unlock

        self
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

      def state_snapshot = state_store.state_snapshot
    end
  end
end
