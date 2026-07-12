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

      def initialize(name, green_run_strategy:, yellow_run_strategy:, red_run_strategy:, state_store:, emitter:)
        @name = name
        @green_run_strategy = green_run_strategy
        @yellow_run_strategy = yellow_run_strategy
        @red_run_strategy = red_run_strategy
        @state_store = state_store
        @emitter = emitter
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

        change_lock(state)

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
        change_lock(State::UNLOCKED)

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

      def change_lock(state)
        before = state_snapshot
        state_store.set_state(state)
        after = state_snapshot
        @emitter.emit(Telemetry::LockChanged) do
          Telemetry::LockChanged.new(
            from_color: before.color,
            to_color: after.color,
            from_state: before.locked_state,
            to_state: after.locked_state
          )
        end
      end
    end
  end
end
