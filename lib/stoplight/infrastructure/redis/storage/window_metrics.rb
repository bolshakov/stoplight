# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Redis
      module Storage
        # Distributed storage for time-windowed light metrics using Redis.
        #
        # == Storage Structure
        #
        # Maintains a running sum and stores per-second counts in a redis Hash. Eviction reads
        # only the out-of-window entries from the sorted set index, subtracts their counts from
        # the running totals, then deletes both the hash fields and the sorted-set members.
        #
        class WindowMetrics < Metrics
          METRICS_FIELDS = %w[last_success_at last_error_json consecutive_errors consecutive_successes].freeze
          private_constant :METRICS_FIELDS

          def initialize(redis:, scripting:, config:, clock:, key_space:)
            @clock = clock
            @redis = redis
            @scripting = scripting
            @metrics_key = key_space.join("window_metrics")
            @ts_index_key = key_space.join("window_metrics", "ts_idx")
            @window_size = T.must(config.window_size).to_i
          end

          def metrics_snapshot
            timestamp = @clock.current_time.to_f

            successes, errors, last_success_at, last_error_json, consecutive_errors, consecutive_successes =
              @scripting.call(
                "window_metrics/metrics_snapshot",
                args: [timestamp, @window_size, *METRICS_FIELDS],
                keys: [@metrics_key, @ts_index_key]
              )

            build_metrics_snapshot(successes:, errors:, consecutive_errors:, consecutive_successes:,
              last_error_json:, last_success_at:)
          end

          def record_success
            timestamp = @clock.current_time.to_f

            @scripting.call(
              "window_metrics/record_success",
              args: [timestamp, @window_size, metrics_ttl],
              keys: [@metrics_key, @ts_index_key]
            )
          end

          def record_failure(exception)
            timestamp = @clock.current_time.to_f

            successes, errors, last_success_at, last_error_json, consecutive_errors, consecutive_successes =
              @scripting.call(
                "window_metrics/record_failure",
                args: [timestamp, serialize_exception(exception, timestamp:), @window_size, metrics_ttl],
                keys: [@metrics_key, @ts_index_key]
              )

            build_metrics_snapshot(successes:, errors:, consecutive_errors:, consecutive_successes:,
              last_error_json:, last_success_at:)
          end

          def clear
            @redis.with do |client|
              client.del(@metrics_key, @ts_index_key)
            end
          end

          private

          def build_metrics_snapshot(successes:, errors:, consecutive_errors:, consecutive_successes:,
            last_error_json:, last_success_at:)
            Domain::MetricsSnapshot.new(
              successes:, errors:,
              consecutive_errors: [consecutive_errors.to_i, errors].min,
              consecutive_successes: [consecutive_successes.to_i, successes].min,
              last_error: deserialize_failure(last_error_json),
              last_success_at: (@clock.at(last_success_at.to_f) if last_success_at)
            )
          end
        end
      end
    end
  end
end
