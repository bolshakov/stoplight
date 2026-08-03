# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module FailSafe
      # Wraps a user-provided error notifier so a failure in the notifier itself
      # cannot escape to callers of fail-safe components.
      #
      # @api private
      class ErrorNotifier
        attr_reader :error_notifier

        def initialize(error_notifier:)
          @error_notifier = error_notifier
        end

        def call(error)
          error_notifier.call(error)
        rescue => notifier_error
          warn "Stoplight error_notifier raised: #{notifier_error.message}"
        end
      end
    end
  end
end
