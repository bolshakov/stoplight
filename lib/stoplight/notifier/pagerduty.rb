# frozen_string_literal: true

module Stoplight
  module Notifier
    # @see Base
    class Pagerduty < Base
      include Generic

      # @return [::Pagerduty]
      def pagerduty
        @object
      end

      private

      def put(message)
        pagerduty.trigger(message)
      end
    end
  end
end
