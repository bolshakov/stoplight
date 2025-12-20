# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module DataStore
      class Memory < Domain::DataStore
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
          # @!attribute buckets
          #   @return [Hash<Integer, Integer>] A hash mapping time buckets to their counts
          private attr_reader :buckets

          # @!attribute running_sum
          #   @return [Integer] The running sum of all increments in the current window
          private attr_accessor :running_sum

          # @!attribute clock
          #   @return [Stoplight::Domain::Clock]
          private attr_reader :clock

          # @param clock [Stoplight::Domain::Clock]
          def initialize(clock:)
            @buckets = Hash.new { |buckets, bucket| buckets[bucket] = 0 }
            @running_sum = 0
            @clock = clock
          end

          # Increment the count at a given timestamp
          def increment
            buckets[current_bucket] += 1
            self.running_sum += 1
          end

          # @param window_start [Time]
          # @return [Integer]
          def sum_in_window(window_start)
            slide_window!(window_start)
            self.running_sum
          end

          private def slide_window!(window_start)
            window_start_ts = window_start.to_i

            loop do
              timestamp, sum = buckets.first
              if timestamp.nil? || timestamp >= window_start_ts
                break
              else
                self.running_sum -= sum
                buckets.shift
              end
            end
          end

          private def current_bucket
            bucket_for_time(clock.current_time)
          end

          private def bucket_for_time(time)
            time.to_i
          end

          def inspect
            "#<#{self.class.name} #{buckets}>"
          end
        end
      end
    end
  end
end
