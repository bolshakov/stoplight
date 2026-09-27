# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Notifier
      # A wrapper around a notifier that provides fail-safe mechanisms using a
      # circuit breaker. It ensures that a notification can gracefully
      # handle failures.
      #
      # @api private
      class FailSafe
        # The underlying notifier being wrapped.
        attr_reader :notifier
        # The underlying notifier being wrapped.
        attr_reader :error_notifier
        attr_reader :circuit_breaker

        # @param notifier The notifier to wrap.
        # @param error_notifier called when wrapped data store fails
        def initialize(notifier:, error_notifier:, circuit_breaker:)
          @notifier = notifier
          @error_notifier = error_notifier
          @circuit_breaker = circuit_breaker
        end

        # Sends a notification using the wrapped notifier with fail-safe mechanisms.
        def notify(info, from_color, to_color, error = nil)
          fallback = proc do |exception|
            error_notifier.call(exception) if exception
            nil
          end #: ^(StandardError?) -> void

          circuit_breaker.run(fallback) do
            notifier.notify(info, from_color, to_color, error)
          end #: void
        end

        # @return [Boolean]
        def ==(other)
          other.is_a?(self.class) && notifier == other.notifier
        end
      end
    end
  end
end
