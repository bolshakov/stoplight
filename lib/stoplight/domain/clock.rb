# frozen_string_literal: true

module Stoplight
  module Domain
    # Abstract wall-clock interface for time-dependent operations.
    #
    # Provides a centralized definition of how Stoplight obtains and
    # interprets time. All time-dependent components should use this
    # interface rather than calling Time methods directly, ensuring
    # consistent time handling across the library.
    #
    # @abstract Subclass and override {#current_time} and {#at} to implement
    #   a custom clock.
    class Clock
      # Returns the current time.
      #
      # @return [Time] current wall-clock time
      def current_time = raise NotImplementedError

      # Converts a Unix timestamp to a Time object.
      #
      # @param timestamp [Integer, Float] Unix timestamp (seconds since epoch)
      # @return [Time] time object representing the given timestamp
      # @return [Time]
      def at(timestamp) = raise NotImplementedError
    end
  end
end
