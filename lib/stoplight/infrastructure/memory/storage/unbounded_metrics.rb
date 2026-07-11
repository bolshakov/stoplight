# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Memory
      module Storage
        # Thread-safe metrics storage for consecutive-error light strategies.
        #
        # Unlike +WindowMetrics+, this class does not track event counts within
        # a time window. It only maintains:
        # - Consecutive success/failure counters (reset on opposite outcome)
        # - Most recent error with timestamp
        # - Most recent success timestamp
        #
        # This is appropriate for circuit breakers using threshold-based strategies
        # (e.g., "open after 5 consecutive failures") rather than rate-based
        # strategies (e.g., "open when error rate exceeds 50%").
        #
        # @note The +#errors+ and +#successes+ fields in the returned +Stoplight::Domain::Metrics+
        #   are always +nil+ since totals aren't tracked.
        #
        class UnboundedMetrics
          def initialize(clock:)
            initialize_metrics
            @clock = clock
            @mutex = Mutex.new
          end

          # Get metrics for the current light
          def metrics_snapshot
            mutex.synchronize do
              Domain::MetricsSnapshot.new(
                errors: nil,
                successes: nil,
                consecutive_errors: consecutive_errors.to_i,
                consecutive_successes: consecutive_successes.to_i,
                last_error: last_error,
                last_success_at: last_success_at
              )
            end
          end

          # Records successful circuit breaker execution
          def record_success
            current_time = clock.current_time

            mutex.synchronize do
              if last_success_at.nil? || current_time > last_success_at
                self.last_success_at = current_time
              end

              self.consecutive_errors = 0
              self.consecutive_successes += 1
            end
          end

          # Records failed circuit breaker execution
          def record_failure(exception)
            current_time = clock.current_time
            failure = Domain::Failure.from_error(exception, time: current_time)

            mutex.synchronize do
              last_error_at = self.last_error_at

              if last_error_at.nil? || failure.occurred_at > last_error_at
                self.last_error = failure
              end

              self.consecutive_errors += 1
              self.consecutive_successes = 0
            end
          end

          def clear
            mutex.synchronize do
              initialize_metrics
            end
          end

          private

          attr_accessor :consecutive_errors
          attr_accessor :consecutive_successes
          attr_accessor :last_error
          attr_accessor :last_success_at

          attr_reader :mutex
          attr_reader :clock

          def initialize_metrics
            @consecutive_errors = 0
            @consecutive_successes = 0
            @last_error = nil
            @last_success_at = nil
          end

          def last_error_at
            last_error&.occurred_at
          end
        end
      end
    end
  end
end
