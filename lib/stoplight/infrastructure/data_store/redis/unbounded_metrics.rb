# frozen_string_literal: true

module Stoplight
  module Infrastructure
    module DataStore
      class Redis
        class UnboundedMetrics < MetricsStorage
          # @!attribute light_name
          #   @return [String]
          private attr_reader :light_name

          # @!attribute redis
          #   @return [RedisClient]
          private attr_reader :redis

          # @!attribute commands
          #   @return [Stoplight::Infrastructure::DataStore::Redis::ScriptManager]
          private attr_reader :script_manager

          # @!attribute metrics_key
          #   @return [String]
          private attr_reader :metrics_key

          def initialize(redis:, script_manager:, light_name:)
            @script_manager = script_manager
            @redis = redis
            @light_name = light_name
            @metrics_key = key("metadata", light_name)
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
              total_consecutive_errors: consecutive_errors.to_i,
              total_consecutive_successes: consecutive_successes.to_i,
              last_error: deserialize_failure(last_error_json),
              last_success_at: (Time.at(last_success_at.to_f) if last_success_at)
            )
          end

          # Records successful circuit breaker execution
          #
          # @return [void]
          def record_success
            timestamp = current_time.to_f

            redis.then do |client|
              client.evalsha(
                script_manager.sha(:unbounded_metrics, :record_success),
                argv: [timestamp],
                keys: [metrics_key]
              )
            end
          end

          # Records failed circuit breaker execution
          #
          # @param exception [StandardError]
          # @return [void]
          def record_failure(exception)
            timestamp = current_time.to_f

            redis.then do |client|
              client.evalsha(
                script_manager.sha(:unbounded_metrics, :record_failure),
                argv: [
                  timestamp,
                  serialize_exception(exception, timestamp:)
                ],
                keys: [metrics_key]
              )
            end
          end

          def reset
          end
        end
      end
    end
  end
end
