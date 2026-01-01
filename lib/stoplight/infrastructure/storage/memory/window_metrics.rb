# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Storage
      module Memory
        # Thread-safe in-memory storage for time-windowed light metrics.
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
        class WindowMetrics < Domain::Storage::Metrics
          # @!attribute metrics
          #   @return [Stoplight::Infrastructure::DataStore::Memory::Metrics]
          private attr_accessor :metrics

          # @!attribute successes
          #   @return [Stoplight::Infrastructure::DataStore::Memory::SlidingWindow]
          private attr_accessor :successes

          # @!attribute errors
          #   @return [Stoplight::Infrastructure::DataStore::Memory::SlidingWindow]
          private attr_accessor :errors

          # @!attribute config
          #   @return [Stoplight::Domain::Config]
          private attr_reader :config

          # @!attribute mutex
          #   @return [Mutex]
          private attr_reader :mutex

          # @!attribute clock
          #   @return [Stoplight::Domain::Clock]
          private attr_reader :clock

          def initialize(config:, clock:)
            @clock = clock
            @config = config
            @mutex = Mutex.new
            @metrics = DataStore::Memory::Metrics.new
            @successes = DataStore::Memory::SlidingWindow.new(clock:)
            @errors = DataStore::Memory::SlidingWindow.new(clock:)
            @window_size = T.must(config.window_size)
          end

          # Get metrics for the current light
          #
          # @return [Stoplight::Domain::Metrics]
          def metrics_snapshot
            mutex.synchronize do
              window_start = (clock.current_time - @window_size)
              errors = self.errors.sum_in_window(window_start)
              successes = self.successes.sum_in_window(window_start)

              Domain::MetricsSnapshot.new(
                errors: errors,
                successes: successes,
                consecutive_errors: [metrics.consecutive_errors, errors].min,
                consecutive_successes: [metrics.consecutive_successes, successes].min,
                last_error: metrics.last_error,
                last_success_at: metrics.last_success_at
              )
            end
          end

          # Records successful circuit breaker execution
          #
          # @return [void]
          def record_success
            mutex.synchronize do
              current_time = clock.current_time
              successes.increment

              if metrics.last_success_at.nil? || current_time > T.must(metrics.last_success_at)
                metrics.last_success_at = current_time
              end

              metrics.consecutive_errors = 0
              metrics.consecutive_successes += 1
            end
          end

          # Records failed circuit breaker execution
          #
          # @param exception [StandardError]
          # @return [void]
          def record_failure(exception)
            mutex.synchronize do
              current_time = clock.current_time
              failure = Domain::Failure.from_error(exception, time: current_time)
              errors.increment

              if metrics.last_error_at.nil? || failure.occurred_at > T.must(metrics.last_error_at)
                metrics.last_error = failure
              end

              metrics.consecutive_errors += 1
              metrics.consecutive_successes = 0
            end
          end

          def clear
            mutex.synchronize do
              self.metrics = DataStore::Memory::Metrics.new
              self.successes = DataStore::Memory::SlidingWindow.new(clock:)
              self.errors = DataStore::Memory::SlidingWindow.new(clock:)
            end
          end
        end
      end
    end
  end
end
