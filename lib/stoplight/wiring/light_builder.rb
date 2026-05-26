# frozen_string_literal: true

require "concurrent/map"

module Stoplight
  module Wiring
    # Constructs a fully-wired Light instance from validated configuration.
    #
    # LightBuilder is the final assembly step in the Light creation pipeline.
    # It receives validated config and dependencies from ConfigurationPipeline
    # and wires together all infrastructure components (data stores, trackers,
    # strategies) needed for a functioning circuit breaker.
    #
    # LightBuilder maintains a global registry (MEMORY_REGISTRY) that ensures
    # the same Memory data store config object always produces the same
    # data store instance:
    #
    #   data_store = Stoplight::DataStore::Memory.new
    #   light1 = Stoplight("foo", data_store: data_store)
    #   light2 = Stoplight("bar", data_store: data_store)
    #   # light1 and light2 share the same underlying memory store
    #
    #   light3 = Stoplight("baz", data_store: Stoplight::DataStore::Memory.new)
    #   # light3 has its own independent store
    #
    # This singleton behavior is keyed by config object identity (object_id),
    # not by value equality.
    #
    # @api private
    class LightBuilder
      FAILOVER_DATA_STORE_CONFIG = Stoplight::DataStore::Memory.new
      private_constant :FAILOVER_DATA_STORE_CONFIG

      MEMORY_REGISTRY = Concurrent::Map.new
      private_constant :MEMORY_REGISTRY

      def initialize(config:)
        @config = config

        @clock = Infrastructure::SystemClock.new
        @name = T.must(config.name)
        @cool_off_time = config.cool_off_time

        @data_store_config = config.data_store
        @error_notifier = config.error_notifier
        @notifiers = config.notifiers
        @traffic_recovery = config.traffic_recovery
        @traffic_control = config.traffic_control

        @error_tracking_policy = Domain::ErrorTrackingPolicy.new(
          tracked: config.tracked_errors,
          skipped: config.skipped_errors
        )
      end

      def build
        Stoplight::Domain::Light.new(
          @name,
          state_store:,
          green_run_strategy:,
          yellow_run_strategy:,
          red_run_strategy:
        )
      end

      def with(
        name: T.undefined,
        cool_off_time: T.undefined,
        threshold: T.undefined,
        recovery_threshold: T.undefined,
        window_size: T.undefined,
        tracked_errors: T.undefined,
        skipped_errors: T.undefined,
        data_store: T.undefined,
        error_notifier: T.undefined,
        notifiers: T.undefined,
        traffic_control: T.undefined,
        traffic_recovery: T.undefined
      )
        self.class.new(
          config: LegacyConfigurationDsl.new(
            name:,
            cool_off_time:,
            threshold:,
            recovery_threshold:,
            window_size:,
            tracked_errors:,
            skipped_errors:,
            traffic_control:,
            traffic_recovery:,
            error_notifier:,
            data_store:,
            notifiers:
          ).configure!(config)
        )
      end

      private

      attr_reader :data_store_config
      attr_reader :error_notifier
      attr_reader :clock
      attr_reader :traffic_control
      attr_reader :traffic_recovery
      attr_reader :config

      def state_store = Stoplight::Infrastructure::Storage::CompatibilityState.new(config:, data_store:)

      # @return [<Stoplight::Notifier::Base>]
      def notifiers
        Array(@notifiers).map do |notifier|
          Infrastructure::Notifier::FailSafe.new(notifier:, error_notifier:)
        end
      end

      def redis_recovery_lock_store
        Infrastructure::Redis::DataStore::RecoveryLockStore.new(
          redis:,
          lock_timeout: config.cool_off_time_in_milliseconds,
          scripting:
        )
      end

      def scripting = Infrastructure::Redis::DataStore::Scripting.new(redis:)

      def memory_recovery_lock_store
        Infrastructure::Memory::DataStore::RecoveryLockStore.new
      end

      def failover_data_store
        create_data_store(FAILOVER_DATA_STORE_CONFIG)
      end

      def data_store
        create_data_store(data_store_config)
      end

      def metrics_store
        Stoplight::Infrastructure::Storage::CompatibilityMetrics.new(config:, data_store:)
      end

      def recovery_lock_store
        Stoplight::Infrastructure::Storage::CompatibilityRecoveryLock.new(config:, data_store:)
      end

      def request_tracker
        Domain::Tracker::Request.new(traffic_control:, notifiers:, config:, metrics_store:, state_store:)
      end

      def recovery_probe_tracker
        Domain::Tracker::RecoveryProbe.new(
          traffic_recovery:,
          notifiers:,
          config:,
          metrics_store: recovery_metrics_store,
          state_store:
        )
      end

      def recovery_metrics_store
        Stoplight::Infrastructure::Storage::CompatibilityRecoveryMetrics.new(config:, data_store:)
      end

      def green_run_strategy
        Domain::Strategies::GreenRunStrategy.new(
          error_tracking_policy: @error_tracking_policy,
          request_tracker:
        )
      end

      def yellow_run_strategy
        Domain::Strategies::YellowRunStrategy.new(
          name: @name,
          error_tracking_policy: @error_tracking_policy,
          notifiers:,
          request_tracker: recovery_probe_tracker,
          red_run_strategy:,
          state_store:,
          metrics_store:,
          recovery_lock_store:,
          config: @config
        )
      end

      def red_run_strategy
        Domain::Strategies::RedRunStrategy.new(name: @name, cool_off_time: @cool_off_time)
      end

      def create_data_store(data_store_config)
        case data_store_config
        when Stoplight::DataStore::Memory
          memory_registry.compute_if_absent(data_store_config.object_id) do
            Infrastructure::Memory::DataStore.new(
              recovery_lock_store: memory_recovery_lock_store,
              clock:
            )
          end
        when Stoplight::DataStore::Redis
          Infrastructure::FailSafe::DataStore.new(
            data_store: Stoplight::Infrastructure::Redis::DataStore.new(
              clock:,
              redis: data_store_config.redis,
              warn_on_clock_skew: data_store_config.warn_on_clock_skew,
              recovery_lock_store: redis_recovery_lock_store,
              scripting:
            ),
            error_notifier:,
            failover_data_store:,
            circuit_breaker: Stoplight.system_light("data_store:fail_safe:redis")
          )
        else
          raise NoMatchingPatternError, data_store_config
        end
      end

      def redis
        case data_store_config
        when DataStore::Redis
          data_store_config.redis
        else
          raise TypeError, "Expected Stoplight::DataStore::Redis, got #{data_store_config.class}"
        end
      end

      def memory_registry = MEMORY_REGISTRY
    end
  end
end
