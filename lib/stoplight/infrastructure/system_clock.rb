# frozen_string_literal: true

module Stoplight
  module Infrastructure
    # Production clock implementation using Ruby's Time class.
    #
    # Default clock for all Stoplight time-dependent operations including
    # bucket calculation, window boundaries, and state transition timestamps.
    #
    # @see Stoplight::Domain::Clock Abstract interface
    class SystemClock < Domain::Clock
      # @return [Time] current system time
      def current_time = Time.now

      # @param timestamp [Integer, Float] Unix timestamp
      # @return [Time] time at the given timestamp
      def at(timestamp) = Time.at(timestamp)
    end
  end
end
