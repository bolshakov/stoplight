# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Storage
      module Memory
        class UnboundedMetrics < Domain::Storage::Metrics
          # @!attribute metrics
          #   @return [Stoplight::Infrastructure::DataStore::Memory::Metrics]
          private attr_accessor :metrics

          # @!attribute mutex
          #   @return [Mutex]
          private attr_reader :mutex

          # @!attribute clock
          #   @return [Stoplight::Domain::Clock]
          private attr_reader :clock

          def initialize(clock:)
            @clock = clock
            @mutex = Mutex.new
            @metrics = DataStore::Memory::Metrics.new
          end

          # Get metrics for the current light
          #
          # @return [Stoplight::Domain::Metrics]
          def metrics_snapshot
            mutex.synchronize do
              Domain::Metrics.new(
                errors: nil,
                successes: nil,
                consecutive_errors: metrics.consecutive_errors.to_i,
                consecutive_successes: metrics.consecutive_successes.to_i,
                last_error: metrics.last_error,
                last_success_at: metrics.last_success_at
              )
            end
          end

          # Records successful circuit breaker execution
          #
          # @return [void]
          def record_success
            current_time = clock.current_time

            mutex.synchronize do
              if metrics.last_success_at.nil? || current_time > metrics.last_success_at
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
            current_time = clock.current_time
            failure = Domain::Failure.from_error(exception, time: current_time)

            mutex.synchronize do
              if metrics.last_error_at.nil? || failure.occurred_at > metrics.last_error_at
                metrics.last_error = failure
              end

              metrics.consecutive_errors += 1
              metrics.consecutive_successes = 0
            end
          end

          def clear
            mutex.synchronize do
              self.metrics = DataStore::Memory::Metrics.new
            end
          end
        end
      end
    end
  end
end
