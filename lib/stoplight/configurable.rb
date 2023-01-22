# frozen_string_literal: true

module Stoplight
  # @api private
  # @abstract include the module and define +#reconfigure+ method
  module Configurable
    # @!attribute [r] configuration
    #   @return [Stoplight::Configuration]
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

    private

    # @param [Stoplight::Configuration]
    # @return [Stoplight::CircuitBreaker]
    def reconfigure(_configuration)
      raise NotImplementedError, "#{self.class.name}#reconfigure is not implemented"
    end
  end
end
