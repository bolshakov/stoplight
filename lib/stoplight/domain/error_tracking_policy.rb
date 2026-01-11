# frozen_string_literal: true

module Stoplight
  module Domain
    # Determines which errors should be traced
    class ErrorTrackingPolicy
      def initialize(tracked:, skipped:)
        @tracked = tracked
        @skipped = skipped
      end

      def track?(error)
        !skipped?(error) && tracked?(error)
      end

      private

      def skipped?(error)
        @skipped.any? { |matcher| matcher === error }
      end

      def tracked?(error)
        @tracked.any? { |matcher| matcher === error }
      end
    end
  end
end
