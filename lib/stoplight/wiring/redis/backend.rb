# frozen_string_literal: true

module Stoplight
  module Wiring
    module Redis
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
