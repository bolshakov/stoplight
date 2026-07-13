# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Redis
      module Storage
        # Distributed storage for time-windowed light metrics using Redis.
        #
        # This class implements sliding window metrics using Redis sorted sets (ZSETs)
        # for efficient time-range queries. Events are bucketed by hour to bound memory
        # usage and enable automatic expiration via Redis TTLs.
        #
        # == Storage Structure
        #
        # Events are stored in hourly buckets as ZSETs:
        #   stoplight:{version}:{system}:{light}:window_metrics:success:1696154400
        #   stoplight:{version}:{system}:{light}:window_metrics:failure:1696154400
        #
        # Each ZSET member is a unique event ID with its timestamp as the score,
        # enabling O(log N) range queries via ZCOUNT.
        #
        # Metadata (consecutive counters, last error) is stored in a hash:
        #   stoplight:{version}:{system}:{light}:window_metrics
        #
        # == Bucket Strategy
        #
        # Fixed 1-hour buckets provide a balance between:
        # - Query efficiency: At most ~25 buckets for a 24-hour window
        # - Memory efficiency: Natural expiration without manual cleanup
        # - Precision: Sub-bucket accuracy via ZSET scores
        #
        # All operations run as Lua scripts for atomicity.
        #
        class WindowMetrics < Metrics
          METRICS_FIELDS = %w[last_success_at last_error_json consecutive_errors consecutive_successes].freeze
          private_constant :METRICS_FIELDS

          def initialize(redis:, scripting:, config:, clock:, key_space:)
            @clock = clock
            @scripting = scripting
            @redis = redis
            @config = config
            @key_space = key_space
            @metrics_key = key_space.key(:window_metrics)
            @window_size = T.must(config.window_size).to_i
          end

          def metrics_snapshot
            window_end_ts = clock.current_time.to_f
            window_start_ts, success_keys, failure_keys = snapshot_window(window_end_ts)

            successes, errors, last_success_at, last_error_json, consecutive_errors, consecutive_successes = scripting.call(
              "window_metrics/metrics_snapshot",
              args: [
                failure_keys.count,
                window_start_ts,
                window_end_ts,
                *METRICS_FIELDS
              ],
              keys: [
                metrics_key,
                *success_keys,
                *failure_keys
              ]
            )

            build_metrics_snapshot(successes:, errors:, consecutive_errors:, consecutive_successes:, last_error_json:,
              last_success_at:)
          end

          def record_success
            timestamp = clock.current_time.to_f

            scripting.call(
              "window_metrics/record_success",
              args: [timestamp, SecureRandom.hex(12), bucket_ttl, metrics_ttl],
              keys: [
                metrics_key,
                successes_key(time: timestamp)
              ]
            )
          end

          def record_failure(exception)
            timestamp = clock.current_time.to_f
            window_start_ts, success_keys, failure_keys = snapshot_window(timestamp)

            successes, errors, last_success_at, last_error_json, consecutive_errors, consecutive_successes = scripting.call(
              "window_metrics/record_failure",
              args: [
                timestamp, SecureRandom.hex(12), serialize_exception(exception, timestamp:), bucket_ttl, metrics_ttl,
                failure_keys.count, window_start_ts, timestamp
              ],
              keys: [
                metrics_key,
                errors_key(time: timestamp),
                *success_keys,
                *failure_keys
              ]
            )

            build_metrics_snapshot(successes:, errors:, consecutive_errors:, consecutive_successes:, last_error_json:,
              last_success_at:)
          end

          def clear
            window_end_ts = clock.current_time.to_f
            failure_keys = failure_bucket_keys(window_end_ts)
            success_keys = success_bucket_keys(window_end_ts)

            redis.with do |client|
              client.del(metrics_key, *failure_keys, *success_keys)
            end
          end

          # Generates a Redis key for a specific metric and time.
          #
          # @param metric [Symbol] The metric type (e.g., "errors").
          # @param time [Time, Numeric] The time for which to generate the key.
          # @return [String] The generated Redis key.
          def bucket_key(metric:, time:)
            key_space.key(:window_metrics, metric, (time.to_i / bucket_size) * bucket_size)
          end

          # Retrieves the list of Redis bucket keys required to cover a specific time window.
          #
          # @param metric The metric type (e.g., "errors").
          # @param window_end  The end time of the window (can be a Time object or a numeric timestamp).
          # @return A list of Redis keys for the buckets that cover the time window.
          # @api private
          def buckets_for_window(metric:, window_end:)
            window_end_ts = window_end.to_i
            window_start_ts = window_end_ts - @window_size

            # Find bucket timestamps that contain any part of the window
            start_bucket = (window_start_ts / bucket_size) * bucket_size

            # End bucket is the last bucket that contains data within our window
            end_bucket = ((window_end_ts - 1) / bucket_size) * bucket_size

            (start_bucket..end_bucket).step(bucket_size).map do |bucket_start|
              bucket_key(metric: metric, time: bucket_start)
            end
          end

          private

          attr_reader :redis
          attr_reader :scripting
          attr_reader :metrics_key
          attr_reader :clock
          attr_reader :key_space

          def bucket_size = 3600 # 1 hour
          def bucket_ttl = @window_size + bucket_size

          def successes_key(time:) = bucket_key(metric: :success, time:)

          def errors_key(time:) = bucket_key(metric: :failure, time:)

          def failure_bucket_keys(window_end) = buckets_for_window(metric: :failure, window_end:)

          def success_bucket_keys(window_end) = buckets_for_window(metric: :success, window_end:)

          def snapshot_window(window_end_ts)
            [window_end_ts - @window_size, success_bucket_keys(window_end_ts), failure_bucket_keys(window_end_ts)]
          end

          def build_metrics_snapshot(successes:, errors:, consecutive_errors:, consecutive_successes:, last_error_json:,
            last_success_at:)
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
