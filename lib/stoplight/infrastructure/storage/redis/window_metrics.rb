# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Storage
      module Redis
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
        # == Atomicity
        #
        # All operations use Lua scripts to ensure atomicity:
        # - record_success: Increments counter and updates metadata in one round-trip
        # - record_failure: Same, plus stores serialized error details
        # - metrics_snapshot: Aggregates across buckets atomically
        #
        class WindowMetrics < Metrics
          # @!attribute redis
          #   @return [::Redis | ConnectionPool<::Redis>]
          private attr_reader :redis

          # @!attribute scripting
          #   @return [Stoplight::Infrastructure::Storage::Redis::Scripting]
          private attr_reader :scripting

          # @!attribute metrics_key
          #   @return [String]
          private attr_reader :metrics_key

          # @!attribute clock
          #   @return [Stoplight::Domain::Clock]
          private attr_reader :clock

          # @!attribute key_space
          #   @return [Stoplight::Infrastructure::Storage::Redis::KeySpace]
          private attr_reader :key_space

          # @param redis [Redis, ConnectionPool<Redis>] Redis client or connection pool
          # @param scripting [Stoplight::Infrastructure::Storage::Redis::Scripting] Lua script executor
          # @param config [Stoplight::Domain::Config]
          # @param clock [Stoplight::Domain::Clock]
          # @param key_space [Stoplight::Infrastructure::Storage::Redis::KeySpace]
          def initialize(redis:, scripting:, config:, clock:, key_space:)
            @clock = clock
            @scripting = scripting
            @redis = redis
            @config = config
            @key_space = key_space
            @metrics_key = key_space.key(:window_metrics)
            @window_size = T.must(config.window_size)
          end

          # Get metrics for the current light
          #
          # @return [Stoplight::Domain::Metrics]
          def metrics_snapshot
            window_end_ts = clock.current_time.to_f
            window_start_ts = window_end_ts - @window_size
            failure_keys = failure_bucket_keys(window_end_ts)
            success_keys = success_bucket_keys(window_end_ts)

            successes, errors, last_success_at, last_error_json, consecutive_errors, consecutive_successes = scripting.call(
              :"window_metrics/metrics_snapshot",
              args: [
                failure_keys.count,
                window_start_ts,
                window_end_ts,
                "last_success_at", "last_error_json", "consecutive_errors", "consecutive_successes"
              ],
              keys: [
                metrics_key,
                *success_keys,
                *failure_keys
              ]
            )
            Domain::MetricsSnapshot.new(
              successes:, errors:,
              consecutive_errors: [consecutive_errors.to_i, errors].min,
              consecutive_successes: [consecutive_successes.to_i, successes].min,
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
              :"window_metrics/record_success",
              args: [timestamp, SecureRandom.hex(12), bucket_ttl, metrics_ttl],
              keys: [
                metrics_key,
                successes_key(time: timestamp)
              ]
            )
          end

          # Records failed circuit breaker execution
          #
          # @param exception [StandardError]
          # @return [void]
          def record_failure(exception)
            timestamp = clock.current_time.to_f

            scripting.call(
              :"window_metrics/record_failure",
              args: [timestamp, SecureRandom.hex(12), serialize_exception(exception, timestamp:), bucket_ttl, metrics_ttl],
              keys: [metrics_key, errors_key(time: timestamp)]
            )
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

          private def bucket_size = 3600 # 1 hour
          private def bucket_ttl = @window_size + bucket_size

          # Retrieves the list of Redis bucket keys required to cover a specific time window.
          #
          # @param metric [Symbol] The metric type (e.g., "errors").
          # @param window_end [Time, Numeric] The end time of the window (can be a Time object or a numeric timestamp).
          # @return [Array<String>] A list of Redis keys for the buckets that cover the time window.
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

          private def successes_key(time:) = bucket_key(metric: :success, time:)

          private def errors_key(time:) = bucket_key(metric: :failure, time:)

          private def failure_bucket_keys(window_end) = buckets_for_window(metric: :failure, window_end:)

          private def success_bucket_keys(window_end) = buckets_for_window(metric: :success, window_end:)
        end
      end
    end
  end
end
