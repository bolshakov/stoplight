# frozen_string_literal: true

module Stoplight
  module Notifier
    # A wrapper around a notifier that provides fail-safe mechanisms using a
    # circuit breaker. It ensures that a notification can gracefully
    # handle failures.
    #
    # @api private
    class FailSafe < Base
      # @!attribute [r] notifier
      #   @return [Stoplight::Notifier::Base] The underlying notifier being wrapped.
      attr_reader :notifier

      # @!attribute [r] error_notifier
      #   @return [Stoplight::Notifier::Base] The underlying notifier being wrapped.
      attr_reader :error_notifier

      class << self
        # Wraps a notifier with fail-safe mechanisms.
        #
        # @param notifier [Stoplight::Notifier::Base] The notifier to wrap.
        # @param error_notifier [Proc] called when wrapped data store fails
        # @return [Stoplight::Notifier::FailSafe] The original notifier if it is already
        #   a +FailSafe+ instance, otherwise a new +FailSafe+ instance.
        def wrap(notifier:, error_notifier:)
          case notifier
          in FailSafe if notifier.error_notifier == error_notifier
            notifier
          in FailSafe
            new(notifier: notifier.notifier, error_notifier:)
          else
            new(notifier:, error_notifier:)
          end
        end
      end

      # Initializes a new instance of the +FailSafe+ class.
      #
      # @param notifier [Stoplight::Notifier::Base] The notifier to wrap.
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
        end

        circuit_breaker.run(fallback) do
          notifier.notify(config, from_color, to_color, error)
        end
      end

      # @return [Boolean]
      def ==(other)
        other.is_a?(FailSafe) && notifier == other.notifier
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
