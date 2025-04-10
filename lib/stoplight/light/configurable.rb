# frozen_string_literal: true

require 'forwardable'

module Stoplight
  class Light < CircuitBreaker
    # Implements light configuration behaviour
    module Configurable
      extend Forwardable

      # @!attribute [r] name
      #   @return [String]
      def_delegator :config, :name

      # Configures data store to be used with this circuit breaker
      #
      # @example
      #   Stoplight('example')
      #     .with_data_store(Stoplight::DataStore::Memory.new)
      #
      # @param data_store [DataStore::Base]
      # @return [Stoplight::CircuitBreaker]
      def with_data_store(data_store)
        reconfigure(config.with(data_store: data_store))
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
        reconfigure(config.with(cool_off_time: cool_off_time))
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
        reconfigure(config.with(threshold: threshold))
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
        reconfigure(config.with(window_size: window_size))
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
        reconfigure(config.with(notifiers: notifiers))
      end

      # @param error_notifier [Proc]
      # @return [Stoplight::CircuitBreaker]
      # @api private
      def with_error_notifier(&error_notifier)
        reconfigure(config.with(error_notifier: error_notifier))
      end

      # Configures a custom list of tracked errors that counts toward the threshold.
      #
      # @example
      #   light = Stoplight('example')
      #     .with_tracked_errors(TimeoutError, NetworkError)
      #   light.run { call_external_service }
      #
      # In the example above, the +TimeoutError+ and +NetworkError+ exceptions
      # will be counted towards the threshold for moving the circuit breaker into the red state.
      # If not configured, the default tracked error is +StandardError+.
      #
      # @param tracked_errors [Array<StandardError>]
      # @return [Stoplight::CircuitBreaker]
      def with_tracked_errors(*tracked_errors)
        reconfigure(config.with(tracked_errors: tracked_errors.dup.freeze))
      end

      # Configures a custom list of skipped errors that do not count toward the threshold.
      # Typically, such errors does not represent a real failure and handled somewhere else
      # in the code.
      #
      # @example
      #   light = Stoplight('example')
      #    .with_skipped_errors(ActiveRecord::RecordNotFound)
      #   light.run { User.find(123) }
      #
      # In the example above, the +ActiveRecord::RecordNotFound+ doesn't
      # move the circuit breaker into the red state.
      #
      # The list of skipped errors is always complemented by the default
      # skipped errors: +NoMemoryError+, +ScriptError+, +SecurityError+, etc.
      # @see +Stoplight::Default::SKIPPED_ERRORS+
      #
      # @param skipped_errors [Array<Exception>]
      # @return [Stoplight::CircuitBreaker]
      def with_skipped_errors(*skipped_errors)
        reconfigure(config.with(skipped_errors: skipped_errors))
      end

      private

      def reconfigure(config)
        self.class.new(config)
      end
    end
  end
end
