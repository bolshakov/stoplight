# frozen_string_literal: true

module Stoplight
  module Domain
    # Base class for creating custom notifiers in Stoplight.
    # This is an abstract class that defines the interface for notifiers.
    #
    # @abstract Subclasses must implement the `notify` method to define custom notification logic.
    # :nocov:
    class StateTransitionNotifier
      # Sends a notification when a Stoplight changes state.
      #
      # @param config [Stoplight::Domain::Config] The Stoplight instance triggering the notification.
      # @param from_color [String] The previous state color of the Stoplight.
      # @param to_color [String] The new state color of the Stoplight.
      # @param error [Exception, nil] The error (if any) that caused the state change.
      # @return [String] The result of the notification process.
      #
      def notify(config, from_color, to_color, error)
        raise NotImplementedError
      end
    end
    # :nocov:
  end
end
