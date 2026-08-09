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
            def initialize(clock:)
              # A hash mapping time buckets to their counts
              @buckets = Hash.new { |buckets, bucket| buckets[bucket] = 0 }
              # The running sum of all increments in the current window
              @running_sum = 0
              @clock = clock
            end

            # Increment the count at the current monotonic second
            def increment
              @buckets[current_bucket] += 1
              @running_sum += 1
            end

            def sum_in_window(window_size)
              slide_window!(monotonic_seconds - window_size)
              @running_sum
            end

            def inspect
              "#<#{self.class.name} #{@buckets}>"
            end

            private

            def slide_window!(window_start)
              window_start_ts = window_start.to_i

              loop do
                timestamp, sum = @buckets.first
                if timestamp.nil? || timestamp >= window_start_ts
                  break
                else
                  @running_sum -= sum.to_i
                  @buckets.shift
                end
              end
            end

            def current_bucket
              monotonic_seconds.to_i
            end

            # Monotonic, so a wall-clock step (NTP) cannot break FIFO eviction;
            # the clock port returns float milliseconds.
            def monotonic_seconds
              @clock.monotonic_time / 1000.0
            end
          end
        end
      end
    end
  end
end
