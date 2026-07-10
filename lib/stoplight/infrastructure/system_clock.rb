# frozen_string_literal: true

module Stoplight
  module Infrastructure
    # Production clock implementation using Ruby's Time class.
    #
    # Default clock for all Stoplight time-dependent operations including
    # bucket calculation, window boundaries, and state transition timestamps.
    #
    class SystemClock
      def current_time = Time.now.utc

      def monotonic_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond)

      def at(timestamp) = Time.at(timestamp).utc
    end
  end
end
