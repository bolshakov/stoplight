# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Memory
      module Storage
        class WindowMetrics
          # Hash-based sliding window for O(1) amortized operations.
          #
          # Maintains a running sum and stores per-second counts in a Hash. Ruby's Hash
          # preserves insertion order (FIFO), allowing efficient removal of expired
          # buckets from the front via +Hash#shift+, with their counts subtracted from
          # the running sum.
          #
          # Performance: O(1) amortized for both reads and writes
          # Memory: Bounded to the number of buckets
          #
          # @note Not thread-safe; synchronization must be handled externally
          # @api private
          class SlidingWindow
            def initialize(clock:, window_size:)
              # A hash mapping time buckets to their counts
              @buckets = Hash.new { |buckets, bucket| buckets[bucket] = 0 }
              # The running sum of all increments in the current window
              @running_sum = 0
              @evicted_through = nil
              @clock = clock
              @window_size = window_size
            end

            # Increment the count at the current monotonic second
            def increment
              timestamp = @clock.monotonic_seconds
              slide_window!(timestamp - @window_size)
              @buckets[timestamp.to_i] += 1
              @running_sum += 1
            end

            def sum_in_window
              slide_window!(@clock.monotonic_seconds - @window_size)
              @running_sum
            end

            def inspect
              "#<#{self.class.name} #{@buckets}>"
            end

            private

            def slide_window!(window_start)
              # A bucket is keyed at the second it was written, which for a whole-second window is
              # always past the boundary in force then, so a boundary already evicted can expire
              # nothing.
              boundary = window_start.floor
              return if boundary == @evicted_through

              @evicted_through = boundary

              loop do
                timestamp, sum = @buckets.first
                if timestamp.nil? || timestamp > boundary
                  break
                else
                  @running_sum -= sum.to_i
                  @buckets.shift
                end
              end
            end
          end
        end
      end
    end
  end
end
