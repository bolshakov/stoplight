# frozen_string_literal: true

module Stoplight
  class Light < CircuitBreaker
    module Runnable # rubocop:disable Style/Documentation
      # @return [String]
      def state
        config.data_store.get_state(config)
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
        failures, state = config.data_store.get_all(config)
        failure = failures.first

        if state == State::LOCKED_GREEN then Color::GREEN
        elsif state == State::LOCKED_RED then Color::RED
        elsif config.below_threshold?(failures.size) then Color::GREEN
        elsif failure&.cool_off_period_exceeded?(config.cool_off_time)
          Color::YELLOW
        else
          Color::RED
        end
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

      private def state_strategy_factory(color)
        @strategies ||= {}
        @strategies[color] ||= case color
        when Color::GREEN
          GreenRunStrategy.new(config)
        when Color::YELLOW
          YellowRunStrategy.new(config)
        else
          RedRunStrategy.new(config)
        end
      end
    end
  end
end
