# frozen_string_literal: true

module Stoplight
  # @abstract include the module and define +#reconfigure+ method
  module CircuitBreaker
    # @!attribute [r] configuration
    #   @return [Stoplight::Configuration]
    #   @api private
    attr_reader :configuration

    # Configures data store to be used with this circuit breaker
    #
    # @example
    #   Stoplight('example')
    #     .with_data_store(Stoplight::DataStore::Memory.new)
    #
    # @param data_store [DataStore::Base]
    # @return [Stoplight::CircuitBreaker]
    def with_data_store(data_store)
      reconfigure(configuration.with(data_store: data_store))
    end

    # Configures cool off time. Stoplight automatically tries to recover
    # from the red state after the cool off time.
    #
    # @example
    #   Stoplight('example')
    #     .cool_off_time(60)
    #
    # @param cool_off_time [Numeric] number of seconds
    # @return [Stoplight::CircuitBreaker]
    def with_cool_off_time(cool_off_time)
      reconfigure(configuration.with(cool_off_time: cool_off_time))
    end

    # Configures custom threshold. After this number of failures Stoplight
    # switches to the red state:
    #
    # @example
    #   Stoplight('example')
    #     .with_threshold(5)
    #
    # @param threshold [Numeric]
    # @return [Stoplight::CircuitBreaker]
    def with_threshold(threshold)
      reconfigure(configuration.with(threshold: threshold))
    end

    # Configures custom window size which Stoplight uses to count failures. For example,
    #
    # @example
    #   Stoplight('example')
    #     .with_threshold(5)
    #     .with_window_size(60)
    #
    # The above example will turn to red light only when 5 errors happen
    # within 60 seconds period.
    #
    # @param window_size [Numeric] number of seconds
    # @return [Stoplight::CircuitBreaker]
    def with_window_size(window_size)
      reconfigure(configuration.with(window_size: window_size))
    end

    # Configures custom notifier
    #
    # @example
    #   io = StringIO.new
    #   notifier = Stoplight::Notifier::IO.new(io)
    #   Stoplight('example')
    #     .with_notifiers([notifier])
    #
    # @param notifiers [Array<Notifier::Base>]
    # @return [Stoplight::CircuitBreaker]
    def with_notifiers(notifiers)
      reconfigure(configuration.with(notifiers: notifiers))
    end

    # @param error_notifier [Proc]
    # @return [Stoplight::CircuitBreaker]
    # @api private
    def with_error_notifier(&error_notifier)
      reconfigure(configuration.with(error_notifier: error_notifier))
    end

    # Configures a custom proc that allows you not to handle an error
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

    # @return [String] one of +locked_green+, +locked_red+, and +unlocked+
    def state
      raise NotImplementedError
    end

    # @return [String] the light's name
    def name
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
    # @raise [Stoplight::Error::RedLight]
    # @return [any]
    def run(&code)
      raise NotImplementedError
    end

    # Locks light in either +State::LOCKED_RED+ or +State::LOCKED_GREEN+
    #
    # @example
    #   light = Stoplight('example-locked')
    #   light.lock(Stoplight::Color::RED)
    #
    # @param color [String] should be either +Color::RED+ or +Color::GREEN+
    # @return [Stoplight::CircuitBreaker] returns locked circuit breaker
    def lock(color)
      raise NotImplementedError
    end

    # Unlocks light and sets it's state to State::UNLOCKED
    #
    # @example
    #   light = Stoplight('example-locked')
    #   light.lock(Stoplight::Color::RED)
    #   light.unlock
    #
    # @return [Stoplight::CircuitBreaker] returns unlocked circuit breaker
    def unlock
      raise NotImplementedError
    end

    private

    # @param [Stoplight::Configuration]
    # @return [Stoplight::CircuitBreaker]
    def reconfigure(_configuration)
      raise NotImplementedError, "#{self.class.name}#reconfigure is not implemented"
    end
  end
end
