# frozen_string_literal: true

module Stoplight
  module Domain
    # Determines which errors should be traced
    class ErrorTrackingPolicy
      def initialize(tracked:, skipped:)
        @tracked = tracked
        @skipped = skipped
      end

      def with(tracked: T.undefined, skipped: T.undefined)
        return self if tracked.is_a?(Undefined) && skipped.is_a?(Undefined)

        self.class.new(
          tracked: tracked.is_a?(Undefined) ? @tracked : Array(tracked),
          skipped: skipped.is_a?(Undefined) ? @skipped : Array(skipped)
        )
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
