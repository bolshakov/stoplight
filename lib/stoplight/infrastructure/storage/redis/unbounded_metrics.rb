# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Storage
      module Redis
        # Distributed metrics storage for consecutive-error light strategies.
        #
        # This class provides a lightweight alternative to +WindowMetrics+ for circuit
        # breakers that don't need time-windowed rate calculations. It tracks only:
        # - Consecutive success/failure counters (reset on opposite outcome)
        # - Most recent error with timestamp and serialized details
        # - Most recent success timestamp
        #
        # == Storage Structure
        #
        # All data is stored in a single Redis hash:
        #   stoplight:{version}:{system}:{light}:metrics
        #
        # Hash fields:
        # - +last_success_at+: Unix timestamp (float) of most recent success
        # - +last_error_at+: Unix timestamp (float) of most recent failure
        # - +last_error_json+: Serialized {Domain::Failure} for error details
        # - +consecutive_successes+: Integer counter, reset to 0 on failure
        # - +consecutive_errors+: Integer counter, reset to 0 on success
        #
        # == Performance Characteristics
        #
        # This implementation is optimized for minimal Redis overhead:
        # - Single hash key per circuit (vs. multiple ZSETs for +WindowMetrics+)
        # - O(1) reads and writes
        # - No time-range queries or bucket management
        # - Low memory footprint
        #
        # == Atomicity
        #
        # Record operations use Lua scripts to ensure atomic read-modify-write:
        # - Consecutive counters are incremented and reset in one round-trip
        # - "Last" timestamps only update if the new event is more recent,
        #   preventing out-of-order writes from corrupting state
        #
        # == When to Use
        #
        # Choose UnboundedMetrics when your circuit breaker strategy is based on
        # consecutive failures (e.g., "open after 5 failures in a row"). Choose
        # {WindowMetrics} when you need error rate calculations (e.g., "open when
        # error rate exceeds 50% over 5 minutes").
        #
        # @note The +errors+ and +successes+ fields in the returned +Stoplight::Domain::Metrics+
        #   are always +nil+ since this class doesn't track windowed totals.
        #
        # @note The metrics hash TTL is refreshed on every write operation. Circuits
        #   with no activity will have their metrics expire, which is generally
        #   desirable for ephemeral or decommissioned lights.
        #
        class UnboundedMetrics < Metrics
          # @!attribute redis
          #   @return [::Redis | ConnectionPool<::Redis>]
          private attr_reader :redis

          # @!attribute scripting
          #   @return [Stoplight::Infrastructure::DataStore::Redis::Scripting]
          private attr_reader :scripting

          # @!attribute metrics_key
          #   @return [String]
          private attr_reader :metrics_key

          # @!attribute clock
          #   @return [Stoplight::Domain::Clock]
          private attr_reader :clock

          def initialize(redis:, scripting:, key_space:, clock:)
            @clock = clock
            @scripting = scripting
            @redis = redis
            @metrics_key = key_space.key(:metrics)
          end

          # Get metrics for the current light
          #
          # @return [Stoplight::Domain::Metrics]
          def metrics_snapshot
            last_success_at, last_error_json, consecutive_errors, consecutive_successes = redis.with do |client|
              client.hmget(
                metrics_key,
                "last_success_at", "last_error_json", "consecutive_errors", "consecutive_successes"
              )
            end

            Domain::MetricsSnapshot.new(
              successes: nil, errors: nil,
              consecutive_errors: consecutive_errors.to_i,
              consecutive_successes: consecutive_successes.to_i,
              last_error: deserialize_failure(last_error_json),
              last_success_at: (clock.at(last_success_at.to_f) if last_success_at)
            )
          end

          # Records successful circuit breaker execution
          #
          # @return [void]
          def record_success
            timestamp = clock.current_time.to_f

            scripting.call(
              :"unbounded_metrics/record_success",
              args: [timestamp, metrics_ttl],
              keys: [metrics_key]
            )
          end

          # Records failed circuit breaker execution
          #
          # @param exception [StandardError]
          # @return [void]
          def record_failure(exception)
            timestamp = clock.current_time.to_f

            scripting.call(
              :"unbounded_metrics/record_failure",
              args: [timestamp, serialize_exception(exception, timestamp:), metrics_ttl],
              keys: [metrics_key]
            )
          end

          def clear
            redis.with do |client|
              client.hdel(metrics_key, "last_success_at", "last_error_json", "consecutive_errors", "consecutive_successes")
            end
          end
        end
      end
    end
  end
end
