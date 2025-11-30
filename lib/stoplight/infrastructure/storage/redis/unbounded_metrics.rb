# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module Storage
      module Redis
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

          def initialize(redis:, scripting:, key_space:)
            @scripting = scripting
            @redis = redis
            @metrics_key = key_space.key(:metadata)
          end

          # Get metrics for the current light
          #
          # @return [Stoplight::Domain::Metrics]
          def metrics_snapshot
            last_success_at, last_error_json, consecutive_errors, consecutive_successes = redis.then do |client|
              client.hmget(
                metrics_key,
                "last_success_at", "last_error_json", "consecutive_errors", "consecutive_successes"
              )
            end

            Domain::Metrics.new(
              successes: nil, errors: nil,
              consecutive_errors: consecutive_errors.to_i,
              consecutive_successes: consecutive_successes.to_i,
              last_error: deserialize_failure(last_error_json),
              last_success_at: (Time.at(last_success_at.to_f) if last_success_at)
            )
          end

          # Records successful circuit breaker execution
          #
          # @return [void]
          def record_success
            timestamp = current_time.to_f

            scripting.call(
              :"unbounded_metrics/record_success",
              args: [timestamp, metadata_ttl],
              keys: [metrics_key]
            )
          end

          # Records failed circuit breaker execution
          #
          # @param exception [StandardError]
          # @return [void]
          def record_failure(exception)
            timestamp = current_time.to_f

            scripting.call(
              :"unbounded_metrics/record_failure",
              args: [timestamp, serialize_exception(exception, timestamp:), metadata_ttl],
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
