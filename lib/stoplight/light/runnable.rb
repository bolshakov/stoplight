# frozen_string_literal: true

module Stoplight
  class Light
    module Runnable # rubocop:disable Style/Documentation
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

      private def state_strategy_factory(color)
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
      private def green_run_strategy
        @green_run_strategy ||= GreenRunStrategy.new(config)
      end

      # @return [Stoplight::Runnable::RunStrategy]
      private def yellow_run_strategy
        @yellow_run_strategy ||= YellowRunStrategy.new(config)
      end

      # @return [Stoplight::Runnable::RunStrategy]
      private def red_run_strategy
        @red_run_strategy ||= RedRunStrategy.new(config)
      end
    end
  end
end
