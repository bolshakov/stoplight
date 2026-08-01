# frozen_string_literal: true

module Stoplight
  module Wiring
    module Redis
      # Redis storage backend with automatic failover to in-memory storage.
      #
      # Every storage component is wrapped in a FailSafe decorator that catches
      # Redis connection errors and falls back to a Memory backend. This ensures
      # circuit breakers remain functional even when Redis is unavailable.
      #
      # The failover behavior is coordinated through a dedicated circuit breaker
      # (`failover_light`) that prevents repeated Redis connection attempts during
      # an outage.
      #
      # @example
      #   backend = Redis::Backend.new(
      #     redis: redis_connection,
      #     scripting: Scripting.new(redis:),
      #     key_space:,
      #     config: light_config,
      #     error_notifier: ->(e) { Logger.error(e) },
      #     failover_light: Stoplight("redis-failover"),
      #     clock: SystemClock.new
      #   )
      #
      #   backend.state_store #=> FailSafe::State wrapping Redis::State
      #
      # @api private
      class Backend < DataStoreBackend
        def initialize(redis:, scripting:, key_space:, config:, error_notifier:, failover_light:, clock:)
          @redis = redis
          @scripting = scripting
          @key_space = key_space
          @clock = clock
          @config = config
          @error_notifier = error_notifier
          @failover_light = failover_light
          @memory_fallback = Memory::Backend.new(clock:, config:)
        end

        def state_store
          @state_store ||= Infrastructure::FailSafe::Storage::State.new(
            primary_store: Infrastructure::Redis::Storage::State.new(
              redis: @redis,
              scripting: @scripting,
              key_space: @key_space,
              cool_off_time: @config.cool_off_time,
              clock: @clock
            ),
            error_notifier: @error_notifier,
            failover_store: @memory_fallback.state_store,
            circuit_breaker: @failover_light
          )
        end

        def recovery_lock_store
          @recovery_lock_store ||= Infrastructure::FailSafe::Storage::RecoveryLock.new(
            primary_store: Infrastructure::Redis::Storage::RecoveryLock.new(
              config: @config, # TODO: pass cool_off_time directly
              redis: @redis,
              scripting: @scripting,
              key_space: @key_space
            ),
            error_notifier: @error_notifier,
            failover_store: @memory_fallback.recovery_lock_store,
            circuit_breaker: @failover_light
          )
        end

        def recovery_metrics_store
          @recovery_metrics_store ||= Infrastructure::FailSafe::Storage::Metrics.new(
            error_notifier: @error_notifier,
            primary_store: Infrastructure::Redis::Storage::RecoveryMetrics.new(
              clock: @clock,
              redis: @redis,
              scripting: @scripting,
              key_space: @key_space
            ),
            failover_store: @memory_fallback.recovery_metrics_store,
            circuit_breaker: @failover_light
          )
        end

        def windowed_metrics_store
          @windowed_metrics_store ||= Infrastructure::FailSafe::Storage::Metrics.new(
            error_notifier: @error_notifier,
            primary_store: Infrastructure::Redis::Storage::WindowMetrics.new(
              config: @config, # TODO: pass window size directly
              redis: @redis,
              scripting: @scripting,
              clock: @clock,
              key_space: @key_space
            ),
            failover_store: @memory_fallback.windowed_metrics_store,
            circuit_breaker: @failover_light
          )
        end

        def unbounded_metrics_store
          @unbounded_metrics_store ||= Infrastructure::FailSafe::Storage::Metrics.new(
            error_notifier: @error_notifier,
            primary_store: Infrastructure::Redis::Storage::UnboundedMetrics.new(
              clock: @clock,
              redis: @redis,
              scripting: @scripting,
              key_space: @key_space
            ),
            failover_store: @memory_fallback.unbounded_metrics_store,
            circuit_breaker: @failover_light
          )
        end
      end
    end
  end
end
