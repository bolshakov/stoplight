# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Memory
      module Storage
        # Thread-safe in-memory storage for time-windowed light @
        #
        # This class tracks success and failure counts within a sliding time window,
        # along with consecutive counters and the most recent error. It's designed
        # for single-process deployments where distributed coordination isn't needed.
        #
        # The sliding window approach provides more accurate error rate calculations
        # than consecutive-error counting, as it considers the full picture of
        # recent traffic rather than just the most recent streak.
        #
        # @note All public methods are synchronized via mutex to ensure thread safety.
        #
        class WindowMetrics
          def initialize(window_size:, clock:)
            @clock = clock
            @mutex = Mutex.new
            @window_size = window_size

            initialize_metrics
          end

          # Get metrics for the current light
          def metrics_snapshot
            @mutex.synchronize { build_metrics_snapshot }
          end

          # Records successful circuit breaker execution
          def record_success
            @mutex.synchronize do
              @successes.increment

              current_time = @clock.current_time

              if @last_success_at.nil? || current_time > T.must(@last_success_at)
                @last_success_at = current_time
              end

              @consecutive_errors = 0
              @consecutive_successes += 1
            end
          end

          # Records failed circuit breaker execution
          def record_failure(exception)
            @mutex.synchronize do
              @errors.increment

              failure = Domain::Failure.from_error(exception, time: @clock.current_time)
              last_error_at = @last_error&.occurred_at

              if last_error_at.nil? || failure.occurred_at > last_error_at
                @last_error = failure
              end

              @consecutive_errors += 1
              @consecutive_successes = 0

              build_metrics_snapshot
            end
          end

          def clear
            @mutex.synchronize do
              initialize_metrics
            end
          end

          private

          def initialize_metrics
            @consecutive_errors = 0
            @consecutive_successes = 0
            @last_error = nil
            @last_success_at = nil
            @successes = SlidingWindow.new(clock: @clock)
            @errors = SlidingWindow.new(clock: @clock)
          end

          def build_metrics_snapshot
            window_start = (@clock.current_time - @window_size)
            errors = @errors.sum_in_window(window_start)
            successes = @successes.sum_in_window(window_start)

            Domain::MetricsSnapshot.new(
              errors:,
              successes:,
              consecutive_errors: [@consecutive_errors, errors].min,
              consecutive_successes: [@consecutive_successes, successes].min,
              last_error: @last_error,
              last_success_at: @last_success_at
            )
          end
        end
      end
    end
  end
end
