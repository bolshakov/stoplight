# frozen_string_literal: true

module Stoplight
  # @abstract
  module CircuitBreaker
    include Configurable

    # Configures a custom proc that allows you to not to handle an error
    # with Stoplight.
    #
    # @example
    #   light = Stoplight('example')
    #     .with_error_handler do |error, handler|
    #       raise error if error.is_a?(ActiveRecord::RecordNotFound)
    #       handle.call(error)
    #     end
    #   light.run { User.find(123) }
    #
    # In the example above, the +ActiveRecord::RecordNotFound+ doesn't
    # move the circuit breaker into the red state.
    #
    # @yieldparam error [Exception]
    # @yieldparam handle [Proc]
    # @return [Stoplight::CircuitBreaker]
    def with_error_handler(&error_handler)
      raise NotImplementedError
    end

    # Configures light with the given fallback block
    #
    # @example
    #   light = Stoplight('example')
    #   light.with_fallback { |error| e.is_a?()ZeroDivisionError) ? 0 : nil }
    #   light.run { 1 / 0} #=> 0
    #
    # @yieldparam error [Exception, nil]
    # @return [Stoplight::CircuitBreaker]
    def with_fallback(&fallback)
      raise NotImplementedError
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
      raise NotImplementedError
    end

    # Runs the given block of code with this circuit breaker
    #
    # @example
    #   light = Stoplight('example')
    #   light.run { 2/0 }
    #
    # @raise [Error::RedLight]
    # @return [any]
    def run(&code)
      raise NotImplementedError
    end

    # Locks light in either +State::LOCKED_RED+ or +State::LOCKED_GREEN+
    #
    # @example
    #   light = Stoplight('example-locked') { true }
    #   light.lock(Stoplight::Color::RED)
    #
    # @param color [String] should be either +Color::RED+ or +Color::GREEN+
    # @return [Stoplight::Light] returns locked light
    def lock(color)
      raise NotImplementedError
    end

    # Unlocks light and sets it's state to State::UNLOCKED
    #
    # @example
    #   light = Stoplight('example-locked') { true }
    #   light.lock(Stoplight::Color::RED)
    #   light.unlock
    #
    # @return [Stoplight::Light] returns unlocked light
    def unlock
      raise NotImplementedError
    end
  end
end
