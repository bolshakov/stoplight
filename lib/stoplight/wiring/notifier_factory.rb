# frozen_string_literal: true

module Stoplight
  module Wiring
    class NotifierFactory
      class << self
        # Wraps a notifier with fail-safe mechanisms.
        #
        # @param notifier [Stoplight::Domain::StateTransitionNotifier] The notifier to wrap.
        # @param error_notifier [Proc] called when wrapped data store fails
        # @return [Stoplight::Notifier::FailSafe] The original notifier if it is already
        #   a +FailSafe+ instance, otherwise a new +FailSafe+ instance.
        def create(notifier:, error_notifier:)
          case notifier
          in Infrastructure::Notifier::FailSafe if notifier.error_notifier == error_notifier
            notifier
          in Infrastructure::Notifier::FailSafe
            Infrastructure::Notifier::FailSafe.new(notifier: notifier.notifier, error_notifier:)
          else
            Infrastructure::Notifier::FailSafe.new(notifier:, error_notifier:)
          end
        end
      end
    end
  end
end
