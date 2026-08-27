# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Redis
      module Storage
        class WindowMetrics < Metrics
          METRICS_FIELDS = %w[last_success_at last_error_json consecutive_errors consecutive_successes].freeze
          private_constant :METRICS_FIELDS

          def initialize(redis:, scripting:, config:, clock:, key_space:)
            @clock = clock
            @redis = redis
            @scripting = scripting
            @metrics_key = key_space.join("window_metrics")
            @success_key = key_space.join("window_metrics", "success")
            @failure_key = key_space.join("window_metrics", "failure")
            @window_size = T.must(config.window_size).to_i
          end

          def metrics_snapshot
            window_end_ts = @clock.current_time.to_f
            window_start_ts = window_end_ts - @window_size

            successes, errors, last_success_at, last_error_json, consecutive_errors, consecutive_successes =
              @scripting.call(
                "window_metrics/metrics_snapshot",
                args: [
                  window_start_ts,
                  window_end_ts,
                  *METRICS_FIELDS
                ],
                keys: [
                  @metrics_key,
                  @success_key,
                  @failure_key
                ]
              )

            build_metrics_snapshot(successes:, errors:, consecutive_errors:, consecutive_successes:,
              last_error_json:, last_success_at:)
          end

          def record_success
            timestamp = @clock.current_time.to_f
            window_start_ts = timestamp - @window_size

            @scripting.call(
              "window_metrics/record_success",
              args: [timestamp, SecureRandom.hex(12), zset_ttl, metrics_ttl, window_start_ts],
              keys: [@metrics_key, @success_key]
            )
          end

          def record_failure(exception)
            timestamp = @clock.current_time.to_f
            window_start_ts = timestamp - @window_size

            successes, errors, last_success_at, last_error_json, consecutive_errors, consecutive_successes =
              @scripting.call(
                "window_metrics/record_failure",
                args: [timestamp, SecureRandom.hex(12), serialize_exception(exception, timestamp:),
                  zset_ttl, metrics_ttl, window_start_ts],
                keys: [@metrics_key, @failure_key, @success_key]
              )

            build_metrics_snapshot(successes:, errors:, consecutive_errors:, consecutive_successes:,
              last_error_json:, last_success_at:)
          end

          def clear
            @redis.with do |client|
              client.del(@metrics_key, @success_key, @failure_key)
            end
          end

          private

          # Extra window so entries written at the beginning of a window are still
          # alive when a metrics_snapshot read arrives at the end of the next one.
          def zset_ttl = @window_size * 2

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
