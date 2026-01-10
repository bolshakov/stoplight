# frozen_string_literal: true

module Stoplight
  module Infrastructure
    # Production clock implementation using Ruby's Time class.
    #
    # Default clock for all Stoplight time-dependent operations including
    # bucket calculation, window boundaries, and state transition timestamps.
    #
    class SystemClock
      def current_time = Time.now

      def at(timestamp) = Time.at(timestamp)
    end
  end
end
