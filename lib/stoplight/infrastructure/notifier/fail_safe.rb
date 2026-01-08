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
        # @!attribute [r] notifier
        #   @return [Stoplight::Domain::StateTransitionNotifier] The underlying notifier being wrapped.
        # @dynamic notifier
        attr_reader :notifier

        # @!attribute [r] error_notifier
        #   @return [Stoplight::Domain::StateTransitionNotifier] The underlying notifier being wrapped.
        # @dynamic error_notifier
        attr_reader :error_notifier

        # Initializes a new instance of the +FailSafe+ class.
        #
        # @param notifier [Stoplight::Domain::StateTransitionNotifier] The notifier to wrap.
        # @param error_notifier [Proc] called when wrapped data store fails
        def initialize(notifier:, error_notifier:)
          @notifier = notifier
          @error_notifier = error_notifier
        end

        # Sends a notification using the wrapped notifier with fail-safe mechanisms.
        #
        # @param config [Stoplight::Domain::Config] The light configuration.
        # @param from_color [String] The initial color of the light.
        # @param to_color [String] The target color of the light.
        # @param error [Exception, nil] An optional error to include in the notification.
        # @return [void]
        def notify(config, from_color, to_color, error = nil)
          fallback = proc do |exception|
            error_notifier.call(exception) if exception
            nil
          end #: ^(StandardError?) -> void

          circuit_breaker.run(fallback) do
            notifier.notify(config, from_color, to_color, error)
          end #: void
        end

        # @return [Boolean]
        def ==(other)
          other.is_a?(self.class) && notifier == other.notifier
        end

        # @return [Stoplight::Light] The circuit breaker used to handle failures.
        private def circuit_breaker
          @circuit_breaker ||= Stoplight.system_light(
            "stoplight:notifier:fail_safe:#{notifier.class.name}",
            notifiers: []
          )
        end
      end
    end
  end
end
